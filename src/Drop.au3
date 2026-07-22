#include-once

; ---------------------------------------------------------------------------
; Drag & drop de fichiers/dossiers via WM_DROPFILES (DragAcceptFiles).
; Gère plusieurs éléments déposés d'un coup ; chaque élément est routé
; par Action_HandleDrop (dossier → samples, fichier → source).
; ---------------------------------------------------------------------------

Global Const $DROP_WM_DROPFILES = 0x0233

Func Drop_Startup($hGui)
    DllCall("shell32.dll", "none", "DragAcceptFiles", "hwnd", $hGui, "bool", True)
    GUIRegisterMsg($DROP_WM_DROPFILES, "Drop_OnWmDropFiles")
EndFunc

Func Drop_OnWmDropFiles($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $lParam
    Local $aRet = DllCall("shell32.dll", "uint", "DragQueryFileW", _
            "handle", $wParam, "uint", 0xFFFFFFFF, "ptr", 0, "uint", 0)
    If @error Then Return 0
    Local $iCount = $aRet[0]
    Local $i, $tBuf
    For $i = 0 To $iCount - 1
        $tBuf = DllStructCreate("wchar[4096]")
        DllCall("shell32.dll", "uint", "DragQueryFileW", _
                "handle", $wParam, "uint", $i, "struct*", $tBuf, "uint", 4096)
        If Not @error Then Action_HandleDrop(DllStructGetData($tBuf, 1))
    Next
    DllCall("shell32.dll", "none", "DragFinish", "handle", $wParam)
    Return 0
EndFunc
