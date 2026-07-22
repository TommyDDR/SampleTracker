#include-once

; ---------------------------------------------------------------------------
; Pilotage du moteur d'analyse (engine/analyze.py) : lancement asynchrone,
; lecture de la progression sur stdout (lignes "PROGRESS n" et "DONE"),
; chargement des résultats depuis le TSV plat.
; Aucune dépendance UI : module testable en CLI.
; ---------------------------------------------------------------------------

Global $g_sPythonPath = ""
Global $g_iEnginePid = 0
Global $g_sEngineBuf = ""
Global $g_iEngineProgress = 0
Global $g_sEngineLastLine = ""
Global $g_sEngineErr = ""
Global $g_sEngineJson = ""
Global $g_sEngineTsv = ""

; Résultats chargés (détections triées par start côté moteur)
Global $g_aDetections[0][6] ; sample, start, duration, gain, gain_db, confidence
Global $g_iDetections = 0
Global $g_aUnknowns[0][3]   ; start, duration, rms_db
Global $g_iUnknowns = 0

Func Engine_LocatePython()
    If $g_sPythonPath <> "" Then Return $g_sPythonPath
    If RunWait(@ComSpec & " /c python --version >nul 2>&1", "", @SW_HIDE) = 0 Then
        $g_sPythonPath = "python"
    ElseIf RunWait(@ComSpec & " /c py --version >nul 2>&1", "", @SW_HIDE) = 0 Then
        $g_sPythonPath = "py"
    EndIf
    Return $g_sPythonPath
EndFunc

; Lance l'analyse en arrière-plan, stdout/stderr capturés.
; @error : 1 = python introuvable, 2 = analyze.py introuvable, 3 = échec lancement.
Func Engine_Start($sSourceWav, $sSamplesDir, $sOutJson, $sOutTsv, $sScript = "")
    Local $sPy = Engine_LocatePython()
    If $sPy = "" Then Return SetError(1, 0, 0)
    If $sScript = "" Then $sScript = @ScriptDir & "\engine\analyze.py"
    If Not FileExists($sScript) Then Return SetError(2, 0, 0)
    FileDelete($sOutJson)
    FileDelete($sOutTsv)
    $g_sEngineJson = $sOutJson
    $g_sEngineTsv = $sOutTsv
    $g_sEngineBuf = ""
    $g_sEngineErr = ""
    $g_iEngineProgress = 0
    $g_sEngineLastLine = ""
    Local $sCmd = $sPy & ' "' & $sScript & '" --source "' & $sSourceWav _
            & '" --samples "' & $sSamplesDir & '" --output "' & $sOutJson _
            & '" --tsv "' & $sOutTsv & '" --progress'
    $g_iEnginePid = Run($sCmd, "", @SW_HIDE, 0x6) ; $STDOUT_CHILD + $STDERR_CHILD
    If $g_iEnginePid = 0 Then Return SetError(3, 0, 0)
    Return 1
EndFunc

Func Engine_IsRunning()
    Return $g_iEnginePid <> 0 And ProcessExists($g_iEnginePid)
EndFunc

; À appeler chaque frame. Draine stdout/stderr (évite le blocage du pipe),
; met à jour la progression. Retour : 0 = en cours, 1 = terminé OK, -1 = échec.
Func Engine_Poll()
    If $g_iEnginePid = 0 Then Return 0
    _Engine_Drain()
    If ProcessExists($g_iEnginePid) Then Return 0
    _Engine_Drain() ; dernier reste après la fin du processus
    $g_iEnginePid = 0
    If StringInStr($g_sEngineBuf, "DONE") And FileExists($g_sEngineTsv) Then Return 1
    Return -1
EndFunc

Func _Engine_Drain()
    Local $sOut = StdoutRead($g_iEnginePid)
    If Not @error And $sOut <> "" Then
        $g_sEngineBuf &= $sOut
        ; dernière valeur PROGRESS
        Local $aProg = StringRegExp($g_sEngineBuf, "PROGRESS (\d+)", 3)
        If Not @error Then $g_iEngineProgress = Number($aProg[UBound($aProg) - 1])
        ; dernière ligne non vide (hors PROGRESS/DONE) pour l'affichage
        Local $aLines = StringSplit(StringStripCR($g_sEngineBuf), @LF)
        Local $i, $sLine
        For $i = $aLines[0] To 1 Step -1
            $sLine = StringStripWS($aLines[$i], 3)
            If $sLine <> "" And Not StringRegExp($sLine, "^(PROGRESS \d+|DONE)$") Then
                $g_sEngineLastLine = $sLine
                ExitLoop
            EndIf
        Next
    EndIf
    Local $sErr = StderrRead($g_iEnginePid)
    If Not @error And $sErr <> "" Then $g_sEngineErr &= $sErr
EndFunc

; Dernière ligne d'erreur décisive (stderr, sinon stdout).
Func Engine_LastError()
    Local $aLines = StringSplit(StringStripCR($g_sEngineErr), @LF)
    Local $i, $sLine
    For $i = $aLines[0] To 1 Step -1
        $sLine = StringStripWS($aLines[$i], 3)
        If $sLine <> "" Then Return $sLine
    Next
    If $g_sEngineLastLine <> "" Then Return $g_sEngineLastLine
    Return "erreur moteur inconnue"
EndFunc

Func Engine_Cancel()
    If Engine_IsRunning() Then
        RunWait(@ComSpec & " /c taskkill /PID " & $g_iEnginePid & " /T /F >nul 2>&1", "", @SW_HIDE)
    EndIf
    $g_iEnginePid = 0
EndFunc

Func Engine_ClearResults()
    ReDim $g_aDetections[0][6]
    ReDim $g_aUnknowns[0][3]
    $g_iDetections = 0
    $g_iUnknowns = 0
EndFunc

; Charge le TSV produit par le moteur. @error : 1 = lecture, 2 = ligne invalide.
Func Engine_LoadResults()
    Engine_ClearResults()
    Local $aLines = FileReadToArray($g_sEngineTsv)
    If @error Then Return SetError(1, 0, 0)
    Local $iD = 0, $iU = 0, $i, $aF
    For $i = 0 To UBound($aLines) - 1
        If StringLeft($aLines[$i], 1) = "D" Then $iD += 1
        If StringLeft($aLines[$i], 1) = "U" Then $iU += 1
    Next
    ReDim $g_aDetections[$iD][6]
    ReDim $g_aUnknowns[$iU][3]
    For $i = 0 To UBound($aLines) - 1
        $aF = StringSplit($aLines[$i], @TAB, 2) ; 0-based
        If $aF[0] = "D" Then
            If UBound($aF) < 7 Then Return SetError(2, 0, 0)
            $g_aDetections[$g_iDetections][0] = $aF[1]
            $g_aDetections[$g_iDetections][1] = Number($aF[2])
            $g_aDetections[$g_iDetections][2] = Number($aF[3])
            $g_aDetections[$g_iDetections][3] = Number($aF[4])
            $g_aDetections[$g_iDetections][4] = Number($aF[5])
            $g_aDetections[$g_iDetections][5] = Number($aF[6])
            $g_iDetections += 1
        ElseIf $aF[0] = "U" Then
            If UBound($aF) < 4 Then Return SetError(2, 0, 0)
            $g_aUnknowns[$g_iUnknowns][0] = Number($aF[1])
            $g_aUnknowns[$g_iUnknowns][1] = Number($aF[2])
            $g_aUnknowns[$g_iUnknowns][2] = Number($aF[3])
            $g_iUnknowns += 1
        EndIf
    Next
    Return 1
EndFunc
