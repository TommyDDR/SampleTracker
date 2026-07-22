; ===========================================================================
; SampleTracker — analyse et décomposition audio (phase 1 : squelette GUI)
;
; Pipeline de rendu conforme à pratiques-rendu-performant.md :
;   - backbuffer DIB 32bpp + memory DC, composition GDI+
;   - un seul blit de présentation par frame (SRCCOPY)
;   - WM_ERASEBKGND intercepté (anti-scintillement)
;   - cache UI à clé scalaire, profiler F3, registre de disposers
; ===========================================================================

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <WinAPIGdi.au3>
#include <GDIPlus.au3>
#include <Misc.au3>
#include <File.au3>
#include <Array.au3>

#include "src\State.au3"
#include "src\Perf.au3"
#include "src\Render.au3"
#include "src\Layout.au3"
#include "src\UiDraw.au3"
#include "src\Actions.au3"
#include "src\Drop.au3"

Opt("MustDeclareVars", 1)
Opt("GUIOnEventMode", 0)

Global Const $APP_FRAME_MS = 1000 / 60
Global $g_hNtdll = DllOpen("ntdll.dll")

Main()

Func Main()
    _GDIPlus_Startup()
    App_CreateWindow()
    App_Loop()
    App_Shutdown()
EndFunc

; --- Fenêtre ---------------------------------------------------------------

Func App_CreateWindow()
    $g_hGui = GUICreate("SampleTracker", 1280, 720, -1, -1, _
            BitOR($WS_OVERLAPPEDWINDOW, $WS_CLIPCHILDREN))
    GUISetBkColor(0x17171C, $g_hGui)
    GUIRegisterMsg($WM_ERASEBKGND, "App_OnEraseBkgnd")
    Drop_Startup($g_hGui)
    GUISetState(@SW_SHOW, $g_hGui)

    Local $aSize = WinGetClientSize($g_hGui)
    Render_Startup($g_hGui, $aSize[0], $aSize[1])
    Layout_Recompute($aSize[0], $aSize[1])
    Ui_Startup()
EndFunc

; Anti-scintillement (doc rendu §2) : "déjà effacé", on repeint tout.
Func App_OnEraseBkgnd($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $wParam, $lParam
    Return 1
EndFunc

; --- Boucle principale (doc rendu §10) -------------------------------------

Func App_Loop()
    While $g_bRunning
        Local $hFrameTimer = TimerInit()

        Perf_Begin($PERF_INPUT)
        App_HandleEvents()
        App_HandlePerfKey()
        Perf_End($PERF_INPUT)

        If Not BitAND(WinGetState($g_hGui), 16) Then ; pas minimisée
            Perf_Begin($PERF_UI)
            Ui_DrawFrame() ; redessine le backbuffer seulement si la clé change
            Perf_End($PERF_UI)

            Perf_Begin($PERF_PRESENT)
            Render_Present()
            Perf_End($PERF_PRESENT)
        EndIf

        Perf_FrameDone($hFrameTimer)
        App_SyncFrame($hFrameTimer)
    WEnd
EndFunc

Func App_HandleEvents()
    While 1
        Local $iMsg = GUIGetMsg()
        If $iMsg = 0 Then ExitLoop
        Switch $iMsg
            Case $GUI_EVENT_CLOSE
                $g_bRunning = False
            Case $GUI_EVENT_RESIZED, $GUI_EVENT_RESTORE, $GUI_EVENT_MAXIMIZE
                App_OnResize()
            Case $GUI_EVENT_MOUSEMOVE
                App_UpdateHover()
            Case $GUI_EVENT_PRIMARYDOWN
                App_OnPrimaryDown()
        EndSwitch
    WEnd
EndFunc

Func App_OnResize()
    Local $aSize = WinGetClientSize($g_hGui)
    If @error Then Return
    If $aSize[0] < 1 Or $aSize[1] < 1 Then Return
    If $aSize[0] = $g_iRenderW And $aSize[1] = $g_iRenderH Then Return
    Render_CreateTargets($aSize[0], $aSize[1])
    Layout_Recompute($aSize[0], $aSize[1])
    $g_sUiCacheKey = "" ; invalider le cache UI (backbuffer neuf)
EndFunc

Func App_UpdateHover()
    Local $aInfo = GUIGetCursorInfo($g_hGui)
    If @error Then Return
    Local $iHit = Layout_HitButton($aInfo[0], $aInfo[1])
    If $iHit <> $g_iHoverButton Then $g_iHoverButton = $iHit
EndFunc

Func App_OnPrimaryDown()
    Local $aInfo = GUIGetCursorInfo($g_hGui)
    If @error Then Return
    Switch Layout_HitButton($aInfo[0], $aInfo[1])
        Case $BTN_OPEN_SOURCE
            Action_OpenSourceDialog()
        Case $BTN_OPEN_SAMPLES
            Action_OpenSamplesDialog()
        Case $BTN_ANALYZE
            Action_Analyze()
    EndSwitch
EndFunc

; Toggle profiler sur F3 (front montant, fenêtre active uniquement).
Func App_HandlePerfKey()
    Local $bDown = _IsPressed("72")
    If $bDown And Not $g_bPerfKeyDown And WinActive($g_hGui) Then
        $g_bPerfEnabled = Not $g_bPerfEnabled
        If Not $g_bPerfEnabled Then WinSetTitle($g_hGui, "", "SampleTracker")
        Perf_Reset()
    EndIf
    $g_bPerfKeyDown = $bDown
EndFunc

; Cadence : NtDelayExecution, précision sub-milliseconde (doc rendu §10).
Func App_SyncFrame($hFrameTimer)
    Local $fRemain = $APP_FRAME_MS - TimerDiff($hFrameTimer)
    If $fRemain <= 0 Then Return
    DllCall($g_hNtdll, "dword", "NtDelayExecution", "bool", False, "int64*", -Int($fRemain * 10000))
EndFunc

; --- Arrêt -----------------------------------------------------------------

Func App_Shutdown()
    Render_RunDisposers()
    Render_Shutdown($g_hGui)
    _GDIPlus_Shutdown()
    DllClose($g_hNtdll)
    GUIDelete($g_hGui)
EndFunc
