#include-once

; ---------------------------------------------------------------------------
; Préférences persistées dans SampleTracker.ini (à côté du script) :
; position et taille de la fenêtre, hauteurs des zones redimensionnables,
; dernière source et dernière bibliothèque chargées.
; ---------------------------------------------------------------------------

Global $g_sIniPath = ""

; Valeurs restaurées au démarrage (appliquées par App_CreateWindow / Main)
Global $g_iWinX = -1
Global $g_iWinY = -1
Global $g_iWinW = 1280
Global $g_iWinH = 720
Global $g_bWinMax = False
Global $g_sLastSource = ""
Global $g_sLastSamples = ""

Func Config_Init()
    $g_sIniPath = @ScriptDir & "\SampleTracker.ini"
EndFunc

Func Config_Load()
    Config_Init()
    $g_iWinX = Int(IniRead($g_sIniPath, "window", "x", -1))
    $g_iWinY = Int(IniRead($g_sIniPath, "window", "y", -1))
    $g_iWinW = Int(IniRead($g_sIniPath, "window", "w", 1280))
    $g_iWinH = Int(IniRead($g_sIniPath, "window", "h", 720))
    $g_bWinMax = (IniRead($g_sIniPath, "window", "maximized", "0") = "1")
    If $g_iWinW < 900 Then $g_iWinW = 900
    If $g_iWinH < 600 Then $g_iWinH = 600
    Config_ClampToDesktop()

    $g_iLayoutSourceH = Int(IniRead($g_sIniPath, "layout", "source_h", $LAYOUT_SOURCE_DEFAULT_H))
    $g_iLayoutSamplesH = Int(IniRead($g_sIniPath, "layout", "samples_h", $LAYOUT_SAMPLES_DEFAULT_H))
    Layout_ClampHeights()

    Engine_SetThreshold(Number(IniRead($g_sIniPath, "engine", "threshold", _
            $ENGINE_THRESHOLD_DEFAULT)))

    $g_sLastSource = IniRead($g_sIniPath, "session", "source", "")
    $g_sLastSamples = IniRead($g_sIniPath, "session", "samples", "")
EndFunc

; Ramène la fenêtre sur le bureau virtuel : une position enregistrée sur un
; écran désormais débranché rendrait la fenêtre invisible.
Func Config_ClampToDesktop()
    If $g_iWinX = -1 And $g_iWinY = -1 Then Return ; centrage par défaut
    Local $iLeft = _WinAPI_GetSystemMetrics(76)   ; SM_XVIRTUALSCREEN
    Local $iTop = _WinAPI_GetSystemMetrics(77)    ; SM_YVIRTUALSCREEN
    Local $iWidth = _WinAPI_GetSystemMetrics(78)  ; SM_CXVIRTUALSCREEN
    Local $iHeight = _WinAPI_GetSystemMetrics(79) ; SM_CYVIRTUALSCREEN
    If $iWidth < 1 Or $iHeight < 1 Then Return
    ; Au moins 120 px de barre de titre doivent rester visibles
    If $g_iWinX + 120 > $iLeft + $iWidth Or $g_iWinX + $g_iWinW - 120 < $iLeft _
            Or $g_iWinY + 40 > $iTop + $iHeight Or $g_iWinY < $iTop - 8 Then
        $g_iWinX = -1
        $g_iWinY = -1
    EndIf
EndFunc

Func Config_Save()
    If $g_sIniPath = "" Then Config_Init()
    Local $bMax = (BitAND(WinGetState($g_hGui), 32) <> 0) ; maximisée
    IniWrite($g_sIniPath, "window", "maximized", $bMax ? "1" : "0")
    ; Ne pas enregistrer la géométrie d'une fenêtre maximisée ou minimisée :
    ; on garde la dernière taille "restaurée" connue.
    If Not $bMax And Not BitAND(WinGetState($g_hGui), 16) Then
        Local $aPos = WinGetPos($g_hGui)
        If IsArray($aPos) Then
            IniWrite($g_sIniPath, "window", "x", $aPos[0])
            IniWrite($g_sIniPath, "window", "y", $aPos[1])
            IniWrite($g_sIniPath, "window", "w", $aPos[2])
            IniWrite($g_sIniPath, "window", "h", $aPos[3])
        EndIf
    EndIf
    IniWrite($g_sIniPath, "layout", "source_h", $g_iLayoutSourceH)
    IniWrite($g_sIniPath, "layout", "samples_h", $g_iLayoutSamplesH)
    IniWrite($g_sIniPath, "engine", "threshold", StringFormat("%.2f", $g_fThreshold))
    IniWrite($g_sIniPath, "session", "source", $g_sSourcePath)
    IniWrite($g_sIniPath, "session", "samples", $g_sSamplesDir)
EndFunc
