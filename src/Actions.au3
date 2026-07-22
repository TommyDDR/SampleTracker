#include-once

; ---------------------------------------------------------------------------
; Actions utilisateur : chargement source, bibliothèque de samples, analyse.
; ---------------------------------------------------------------------------

Func App_IsAnalyzeReady()
    Return $g_sSourceWav <> "" And UBound($g_aSampleFiles) > 0
EndFunc

; --- Fichier source --------------------------------------------------------

Func Action_OpenSourceDialog()
    Local $sPath = FileOpenDialog("Choisir le fichier source", @WorkingDir, _
            "Audio/Vidéo (*.mp3;*.wav;*.mp4)", 3, "", $g_hGui)
    If @error Then Return
    Action_LoadSource($sPath)
EndFunc

Func Action_LoadSource($sPath)
    If Not StringRegExp($sPath, "(?i)\.(mp3|wav|mp4)$") Then
        Ui_SetStatus("Format non supporté (MP3, WAV, MP4 uniquement) : " & Action_FileName($sPath), 2)
        Return
    EndIf
    If Not FileExists($sPath) Then
        Ui_SetStatus("Fichier introuvable : " & $sPath, 2)
        Return
    EndIf
    Ffmpeg_Cancel() ; annule une extraction précédente éventuelle
    Action_AbortAnalysis()
    Waveform_Reset()
    $g_sSourcePath = $sPath
    $g_sSourceWav = ""
    $g_fSourceDuration = 0
    $g_iSourceRate = 0
    Ffmpeg_StartExtract($sPath, $g_sWorkDir & "\source.wav", $g_sWorkDir & "\ffmpeg.log")
    If @error Then
        Ui_SetStatus("ffmpeg introuvable : placer ffmpeg.exe dans bin\ ou dans le PATH", 2)
        $g_sSourcePath = ""
        Return
    EndIf
    $g_bExtracting = True
    $g_hExtractTimer = TimerInit()
    Ui_SetStatus("Extraction audio : " & Action_FileName($sPath), 0)
EndFunc

; Appelé chaque frame : détecte la fin de l'extraction ffmpeg.
Func Action_PollExtraction()
    If Not $g_bExtracting Then Return
    If Ffmpeg_IsRunning() Then Return
    $g_bExtracting = False
    $g_iFfmpegPid = 0
    Local $iRate, $iChannels, $iBits
    Local $fDuration = Wav_ReadInfo($g_sWorkDir & "\source.wav", $iRate, $iChannels, $iBits)
    If @error Or $fDuration <= 0 Then
        Ui_SetStatus("Échec extraction audio : " & Ffmpeg_LastErrorLine(), 2)
        $g_sSourcePath = ""
        Return
    EndIf
    $g_sSourceWav = $g_sWorkDir & "\source.wav"
    $g_fSourceDuration = $fDuration
    $g_iSourceRate = $iRate
    Waveform_Start($g_sSourceWav) ; calcul des pics en arrière-plan
    Ui_SetStatus(StringFormat("Source prête : %s (%.2f s)", Action_FileName($g_sSourcePath), $fDuration), 1)
EndFunc

; --- Bibliothèque de samples -----------------------------------------------

Func Action_OpenSamplesDialog()
    Local $sDir = FileSelectFolder("Choisir le dossier de la bibliothèque de samples", "", 0, "", $g_hGui)
    If @error Then Return
    Action_LoadSamplesDir($sDir)
EndFunc

Func Action_LoadSamplesDir($sDir)
    If Not StringInStr(FileGetAttrib($sDir), "D") Then
        Ui_SetStatus("Pas un dossier : " & $sDir, 2)
        Return
    EndIf
    ; Scan récursif, tri intégré, chemins relatifs au dossier racine
    Local $aFiles = _FileListToArrayRec($sDir, "*.mp3;*.wav", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_SORT, $FLTAR_RELPATH)
    If @error Or $aFiles[0] = 0 Then
        Ui_SetStatus("Aucun sample MP3/WAV trouvé dans : " & $sDir, 2)
        Return
    EndIf
    Local $aNames[$aFiles[0]]
    Local $i
    For $i = 1 To $aFiles[0]
        $aNames[$i - 1] = $aFiles[$i]
    Next
    Action_AbortAnalysis()
    $g_aSampleFiles = $aNames
    $g_sSamplesDir = $sDir
    Ui_SetStatus($aFiles[0] & " samples chargés depuis " & $sDir, 1)
EndFunc

; --- Drag & drop -----------------------------------------------------------

; Dossier → bibliothèque de samples ; fichier → source.
Func Action_HandleDrop($sPath)
    If StringInStr(FileGetAttrib($sPath), "D") Then
        Action_LoadSamplesDir($sPath)
    Else
        Action_LoadSource($sPath)
    EndIf
EndFunc

; --- Analyse (phase 5) -----------------------------------------------------

Func Action_Analyze()
    If Not App_IsAnalyzeReady() Or $g_bAnalyzing Then Return
    Engine_Start($g_sSourceWav, $g_sSamplesDir, _
            $g_sWorkDir & "\result.json", $g_sWorkDir & "\result.tsv")
    If @error Then
        Switch @error
            Case 1
                Ui_SetStatus("Python introuvable (requis pour le moteur) : installer Python 3.10+ avec numpy", 2)
            Case 2
                Ui_SetStatus("engine\analyze.py introuvable", 2)
            Case Else
                Ui_SetStatus("Échec du lancement du moteur", 2)
        EndSwitch
        Return
    EndIf
    Engine_ClearResults()
    $g_iResultsVersion += 1
    $g_bAnalyzing = True
    $g_hAnalyzeTimer = TimerInit()
    Ui_SetStatus("Analyse en cours…", 0)
EndFunc

; Appelé chaque frame : détecte la fin de l'analyse.
Func Action_PollEngine()
    If Not $g_bAnalyzing Then Return
    Local $iRes = Engine_Poll()
    If $iRes = 0 Then Return
    $g_bAnalyzing = False
    If $iRes = 1 Then
        Engine_LoadResults()
        If @error Then
            Ui_SetStatus("Résultats illisibles (TSV) : " & $g_sEngineTsv, 2)
        Else
            Ui_SetStatus(StringFormat("Analyse terminée en %.1f s : %d détection(s), %d inconnu(s)", _
                    TimerDiff($g_hAnalyzeTimer) / 1000, $g_iDetections, $g_iUnknowns), 1)
        EndIf
    Else
        Ui_SetStatus("Échec analyse : " & Engine_LastError(), 2)
    EndIf
    $g_iResultsVersion += 1
EndFunc

; Annule l'analyse et invalide les résultats (source/bibliothèque changée).
Func Action_AbortAnalysis()
    If $g_bAnalyzing Then
        Engine_Cancel()
        $g_bAnalyzing = False
    EndIf
    Engine_ClearResults()
    $g_iResultsVersion += 1
EndFunc

; --- Helpers ---------------------------------------------------------------

Func Action_FileName($sPath)
    Return StringRegExpReplace($sPath, "^.*\\", "")
EndFunc
