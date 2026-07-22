#include-once

; ---------------------------------------------------------------------------
; Pipeline de rendu (doc rendu §1, §3, §11) :
;   DIB section 32bpp dans un memory DC ← composé via GDI+
;   Render_Present() : un seul BitBlt memDC → DC fenêtre (SRCCOPY)
; Le backbuffer suit la taille client de la fenêtre (recréé au resize).
; ---------------------------------------------------------------------------

Global Const $RENDER_SRCCOPY = 0x00CC0020
Global Const $RENDER_COLORONCOLOR = 3
Global Const $RENDER_TEXT_HINT = 5 ; ClearTypeGridFit (backbuffer opaque)

Global $g_hPresentDC = 0
Global $g_hMemDC = 0
Global $g_hDib = 0
Global $g_hDibOld = 0
Global $g_hGfx = 0
Global $g_iRenderW = 0
Global $g_iRenderH = 0

; Registre de disposers (doc rendu §11) — register-on-create, idempotents.
Global $g_aDisposers[0]

Func Render_Startup($hGui, $iW, $iH)
    $g_hPresentDC = _WinAPI_GetDC($hGui)
    _WinAPI_SetStretchBltMode($g_hPresentDC, $RENDER_COLORONCOLOR)
    Render_CreateTargets($iW, $iH)
EndFunc

; Pattern "recreate" : commence par disposer (reconstruction sans fuite).
Func Render_CreateTargets($iW, $iH)
    Render_DisposeTargets()
    $g_iRenderW = $iW
    $g_iRenderH = $iH
    $g_hMemDC = _WinAPI_CreateCompatibleDC($g_hPresentDC)
    $g_hDib = _WinAPI_CreateDIB($iW, $iH)
    $g_hDibOld = _WinAPI_SelectObject($g_hMemDC, $g_hDib)
    $g_hGfx = _GDIPlus_GraphicsCreateFromHDC($g_hMemDC)
    Render_ApplyModes($g_hGfx)
EndFunc

; Bloc de modes GDI+ (doc rendu §3) — à appliquer sur CHAQUE graphics créé.
Func Render_ApplyModes($hGfx)
    _GDIPlus_GraphicsSetInterpolationMode($hGfx, 5) ; NearestNeighbor
    _GDIPlus_GraphicsSetPixelOffsetMode($hGfx, 2)   ; Half
    _GDIPlus_GraphicsSetSmoothingMode($hGfx, 0)     ; pas d'antialiasing des formes
    _GDIPlus_GraphicsSetTextRenderingHint($hGfx, $RENDER_TEXT_HINT)
EndFunc

; Présentation : un seul blit par frame (doc rendu §1-2).
Func Render_Present()
    _WinAPI_BitBlt($g_hPresentDC, 0, 0, $g_iRenderW, $g_iRenderH, _
            $g_hMemDC, 0, 0, $RENDER_SRCCOPY)
EndFunc

; Enregistre le backbuffer courant en PNG (contrôle visuel / diagnostic).
; Le rendu allant directement dans le DC de la fenêtre, une capture d'écran
; classique ne voit rien : on relit donc la DIB.
Func Render_SaveBackbuffer($sPath)
    If $g_hDib = 0 Then Return SetError(1, 0, 0)
    Local $hBitmap = _GDIPlus_BitmapCreateFromHBITMAP($g_hDib)
    If @error Then Return SetError(2, 0, 0)
    _GDIPlus_ImageSaveToFile($hBitmap, $sPath)
    Local $iErr = @error
    _GDIPlus_ImageDispose($hBitmap)
    If $iErr Then Return SetError(3, 0, 0)
    Return 1
EndFunc

Func Render_DisposeTargets()
    If $g_hGfx <> 0 Then
        _GDIPlus_GraphicsDispose($g_hGfx) ; toujours le Graphics AVANT son bitmap
        $g_hGfx = 0
    EndIf
    If $g_hMemDC <> 0 Then
        _WinAPI_SelectObject($g_hMemDC, $g_hDibOld)
        _WinAPI_DeleteObject($g_hDib)
        _WinAPI_DeleteDC($g_hMemDC)
        $g_hMemDC = 0
        $g_hDib = 0
        $g_hDibOld = 0
    EndIf
EndFunc

Func Render_Shutdown($hGui)
    Render_DisposeTargets()
    If $g_hPresentDC <> 0 Then
        _WinAPI_ReleaseDC($hGui, $g_hPresentDC)
        $g_hPresentDC = 0
    EndIf
EndFunc

; --- Registre de disposers -------------------------------------------------

Func Render_RegisterDisposer($sFuncName)
    Local $i
    For $i = 0 To UBound($g_aDisposers) - 1
        If $g_aDisposers[$i] = $sFuncName Then Return ; dedup
    Next
    ReDim $g_aDisposers[UBound($g_aDisposers) + 1]
    $g_aDisposers[UBound($g_aDisposers) - 1] = $sFuncName
EndFunc

Func Render_RunDisposers()
    Local $i
    For $i = 0 To UBound($g_aDisposers) - 1
        Call($g_aDisposers[$i])
    Next
EndFunc
