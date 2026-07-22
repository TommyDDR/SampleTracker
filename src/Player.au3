#include-once

; ---------------------------------------------------------------------------
; Lecture audio via MCI (winmm.dll) : lecture de la source (WAV extrait) avec
; curseur de position, et lecture ponctuelle d'un sample (prévisualisation).
; Deux alias MCI distincts : la prévisualisation d'un sample n'interrompt pas
; la lecture de la source.
; Aucune dépendance UI : module testable en CLI.
; ---------------------------------------------------------------------------

Global Const $PLAYER_ALIAS_SRC = "stSource"
Global Const $PLAYER_ALIAS_SMP = "stSample"

Global $g_bSrcOpen = False
Global $g_bSrcPlaying = False
Global $g_bSrcPaused = False
Global $g_fPlayCursor = 0       ; position du curseur en secondes (départ de lecture)
Global $g_fPlayPos = 0          ; position mémoïsée, rafraîchie par Player_Poll
Global $g_sSmpPlaying = ""      ; sample en prévisualisation ("" si aucun)

; Envoie une commande MCI. Retourne la chaîne de retour ("" si erreur), @error <> 0 si échec.
Func Player_Mci($sCmd)
    Local $tBuf = DllStructCreate("wchar[512]")
    Local $aRet = DllCall("winmm.dll", "dword", "mciSendStringW", _
            "wstr", $sCmd, "struct*", $tBuf, "uint", 512, "hwnd", 0)
    If @error Then Return SetError(1, 0, "")
    If $aRet[0] <> 0 Then Return SetError($aRet[0], 0, "")
    Return DllStructGetData($tBuf, 1)
EndFunc

; --- Source ----------------------------------------------------------------

; Ouvre le WAV source (ferme l'éventuel précédent). @error <> 0 si échec MCI.
Func Player_OpenSource($sWavPath)
    Player_CloseSource()
    If Not FileExists($sWavPath) Then Return SetError(1, 0, 0)
    Player_Mci('open "' & $sWavPath & '" type waveaudio alias ' & $PLAYER_ALIAS_SRC)
    If @error Then Return SetError(2, 0, 0)
    Player_Mci("set " & $PLAYER_ALIAS_SRC & " time format milliseconds")
    $g_bSrcOpen = True
    $g_bSrcPlaying = False
    $g_bSrcPaused = False
    $g_fPlayCursor = 0
    Return 1
EndFunc

Func Player_CloseSource()
    If $g_bSrcOpen Then Player_Mci("close " & $PLAYER_ALIAS_SRC)
    $g_bSrcOpen = False
    $g_bSrcPlaying = False
    $g_bSrcPaused = False
EndFunc

; Lecture depuis le curseur (ou reprise si en pause).
Func Player_Play()
    If Not $g_bSrcOpen Then Return
    If $g_bSrcPaused Then
        Player_Mci("resume " & $PLAYER_ALIAS_SRC)
        $g_bSrcPaused = False
        $g_bSrcPlaying = True
        Return
    EndIf
    Player_Mci("play " & $PLAYER_ALIAS_SRC & " from " & Int($g_fPlayCursor * 1000))
    If @error Then Return
    $g_fPlayPos = $g_fPlayCursor
    $g_bSrcPlaying = True
    $g_bSrcPaused = False
EndFunc

Func Player_Pause()
    If Not $g_bSrcOpen Or Not $g_bSrcPlaying Then Return
    Player_Mci("pause " & $PLAYER_ALIAS_SRC)
    $g_bSrcPaused = True
    $g_bSrcPlaying = False
EndFunc

Func Player_TogglePlayPause()
    If $g_bSrcPlaying Then
        Player_Pause()
    Else
        Player_Play()
    EndIf
EndFunc

; Arrêt : la tête de lecture revient au curseur défini par l'utilisateur.
Func Player_Stop()
    If Not $g_bSrcOpen Then Return
    Player_Mci("stop " & $PLAYER_ALIAS_SRC)
    Player_Mci("seek " & $PLAYER_ALIAS_SRC & " to " & Int($g_fPlayCursor * 1000))
    $g_bSrcPlaying = False
    $g_bSrcPaused = False
EndFunc

; Déplace le curseur ; si la lecture est en cours, elle repart de là.
Func Player_SetCursor($fSeconds)
    If $fSeconds < 0 Then $fSeconds = 0
    $g_fPlayCursor = $fSeconds
    $g_fPlayPos = $fSeconds
    If Not $g_bSrcOpen Then Return
    If $g_bSrcPlaying Then
        Player_Mci("play " & $PLAYER_ALIAS_SRC & " from " & Int($fSeconds * 1000))
    Else
        Player_Mci("seek " & $PLAYER_ALIAS_SRC & " to " & Int($fSeconds * 1000))
        $g_bSrcPaused = False
    EndIf
EndFunc

; Position courante en secondes (valeur mémoïsée : le rendu ne doit pas
; interroger MCI par frame — cf. pratiques de rendu §7.4).
Func Player_Position()
    If $g_bSrcPlaying Then Return $g_fPlayPos
    Return $g_fPlayCursor
EndFunc

; Rafraîchit la position et détecte la fin de lecture (à appeler chaque
; frame). Coût nul si aucune lecture en cours.
Func Player_Poll()
    If Not $g_bSrcOpen Or Not $g_bSrcPlaying Then Return
    Local $sMode = Player_Mci("status " & $PLAYER_ALIAS_SRC & " mode")
    If $sMode <> "playing" Then
        $g_bSrcPlaying = False
        $g_bSrcPaused = False
        $g_fPlayPos = $g_fPlayCursor
        Player_Mci("seek " & $PLAYER_ALIAS_SRC & " to " & Int($g_fPlayCursor * 1000))
        Return
    EndIf
    Local $sPos = Player_Mci("status " & $PLAYER_ALIAS_SRC & " position")
    If Not @error And $sPos <> "" Then $g_fPlayPos = Number($sPos) / 1000
EndFunc

; --- Prévisualisation d'un sample -----------------------------------------

; Joue un fichier sample (alias séparé). MP3 supporté via mpegvideo.
Func Player_PlaySample($sPath)
    Player_StopSample()
    If Not FileExists($sPath) Then Return SetError(1, 0, 0)
    Local $sType = StringRegExp($sPath, "(?i)\.mp3$") ? "mpegvideo" : "waveaudio"
    Player_Mci('open "' & $sPath & '" type ' & $sType & " alias " & $PLAYER_ALIAS_SMP)
    If @error Then Return SetError(2, 0, 0)
    Player_Mci("play " & $PLAYER_ALIAS_SMP & " from 0")
    If @error Then
        Player_Mci("close " & $PLAYER_ALIAS_SMP)
        Return SetError(3, 0, 0)
    EndIf
    $g_sSmpPlaying = $sPath
    Return 1
EndFunc

Func Player_StopSample()
    If $g_sSmpPlaying = "" Then Return
    Player_Mci("close " & $PLAYER_ALIAS_SMP)
    $g_sSmpPlaying = ""
EndFunc

; Libère l'alias quand la prévisualisation est terminée (appelé chaque frame).
Func Player_PollSample()
    If $g_sSmpPlaying = "" Then Return
    Local $sMode = Player_Mci("status " & $PLAYER_ALIAS_SMP & " mode")
    If $sMode <> "playing" Then Player_StopSample()
EndFunc

Func Player_Shutdown()
    Player_StopSample()
    Player_CloseSource()
EndFunc
