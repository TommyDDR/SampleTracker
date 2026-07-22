; ===========================================================================
; Test : correspondance des identifiants GUISetCursor.
; Lancement : AutoIt3.exe tests\CursorTest.au3   (exit 0 = PASS)
;
; La table d'identifiants de GUISetCursor ne correspond pas aux constantes
; système (IDC_*). Ce test la relève en comparant le handle du curseur actif
; à ceux des curseurs standard, et verrouille les trois valeurs utilisées par
; l'interface. Il alerte si une version d'AutoIt change cette table.
; ===========================================================================

#include <GUIConstantsEx.au3>

Opt("MustDeclareVars", 1)

Global $g_iFailures = 0
Global $g_aStdId[9] = [32512, 32515, 32649, 32513, 32514, 32646, 32642, 32645, 32650]
Global $g_aStdName[9] = ["ARROW", "CROSS", "HAND", "IBEAM", "WAIT", "SIZEALL", _
        "SIZENWSE", "SIZENS", "APPSTARTING"]
Global $g_hGui = 0
Global $g_aWinPos[4]

Main()

Func Main()
    $g_hGui = GUICreate("CursorTest", 400, 300, 100, 100)
    GUISetState(@SW_SHOW, $g_hGui)
    Sleep(300)
    $g_aWinPos = WinGetPos($g_hGui)
    If Not IsArray($g_aWinPos) Then
        ConsoleWrite("SKIP : fenêtre indisponible" & @CRLF)
        Exit 2
    EndIf

    ; Valeurs utilisées par l'interface (src : $CURSOR_HAND / ARROW / SIZENS)
    Assert(_CursorName(0) = "HAND", "id 0 = main (zone cliquable)")
    Assert(_CursorName(2) = "ARROW", "id 2 = flèche standard")
    Assert(_CursorName(11) = "SIZENS", "id 11 = double flèche verticale (poignée)")
    ; Piège documenté : l'id 1 n'est pas la flèche mais le curseur d'attente
    Assert(_CursorName(1) = "APPSTARTING", "id 1 = flèche + sablier (à ne pas utiliser au survol)")

    GUIDelete($g_hGui)
    If $g_iFailures > 0 Then
        ConsoleWrite("FAIL : " & $g_iFailures & " échec(s)" & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS" & @CRLF)
    Exit 0
EndFunc

; Applique l'identifiant puis identifie le curseur système réellement affiché.
Func _CursorName($iId)
    GUISetCursor($iId, 1, $g_hGui)
    ; un mouvement est nécessaire pour que Windows applique le curseur
    MouseMove($g_aWinPos[0] + 200 + Mod($iId, 2), $g_aWinPos[1] + 150, 0)
    Sleep(60)
    Local $tInfo = DllStructCreate("dword cbSize;dword flags;handle hCursor;long x;long y")
    DllStructSetData($tInfo, "cbSize", DllStructGetSize($tInfo))
    Local $aRet = DllCall("user32.dll", "bool", "GetCursorInfo", "struct*", $tInfo)
    If @error Or Not $aRet[0] Then Return "erreur"
    Local $hCur = DllStructGetData($tInfo, "hCursor")
    Local $i, $aStd
    For $i = 0 To UBound($g_aStdId) - 1
        $aStd = DllCall("user32.dll", "handle", "LoadCursorW", "hwnd", 0, "int", $g_aStdId[$i])
        If Not @error And $aStd[0] = $hCur Then Return $g_aStdName[$i]
    Next
    Return "autre"
EndFunc

Func Assert($bCond, $sLabel)
    If $bCond Then
        ConsoleWrite("  ok  " & $sLabel & @CRLF)
    Else
        ConsoleWrite("  KO  " & $sLabel & @CRLF)
        $g_iFailures += 1
    EndIf
EndFunc
