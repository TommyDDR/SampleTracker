; ===========================================================================
; Test phase 5 : pilotage du moteur depuis AutoIt (Engine.au3).
; Lancement : AutoIt3.exe tests\Phase5Test.au3   (exit 0 = PASS, 2 = SKIP)
; Génère 2 samples (sinus 500 et 1200 Hz) + un mix avec positions connues,
; lance engine/analyze.py via Engine_Start, poll jusqu'à la fin, vérifie
; la progression et le parsing TSV.
; ===========================================================================

#include "..\src\Ffmpeg.au3"
#include "..\src\Engine.au3"

Opt("MustDeclareVars", 1)

Global $g_iFailures = 0

Main()

Func Main()
    Local $sProjectBin = @ScriptDir & "\..\bin\ffmpeg.exe"
    If FileExists($sProjectBin) Then $g_sFfmpegPath = $sProjectBin
    Local $sFf = Ffmpeg_Locate()
    If $sFf = "" Then
        ConsoleWrite("SKIP : ffmpeg introuvable" & @CRLF)
        Exit 2
    EndIf
    If Engine_LocatePython() = "" Then
        ConsoleWrite("SKIP : python introuvable" & @CRLF)
        Exit 2
    EndIf

    Local $sDir = @TempDir & "\SampleTrackerTest5"
    DirCreate($sDir)
    DirCreate($sDir & "\samples")

    ; Samples : 0.4 s de sinus, volumes < 1 pour éviter tout clip au mix
    RunWait(@ComSpec & ' /c ""' & $sFf & '" -y -hide_banner -loglevel error' _
            & ' -f lavfi -i "sine=frequency=500:duration=0.4" -af volume=0.6' _
            & ' -ac 1 -ar 44100 -c:a pcm_s16le "' & $sDir & '\samples\tone500.wav""', "", @SW_HIDE)
    RunWait(@ComSpec & ' /c ""' & $sFf & '" -y -hide_banner -loglevel error' _
            & ' -f lavfi -i "sine=frequency=1200:duration=0.4" -af volume=0.6' _
            & ' -ac 1 -ar 44100 -c:a pcm_s16le "' & $sDir & '\samples\tone1200.wav""', "", @SW_HIDE)

    ; Mix : tone500 @ 0.5 s (gain 0.8), tone1200 @ 1.5 s (gain 0.5), durée 2.5 s
    RunWait(@ComSpec & ' /c ""' & $sFf & '" -y -hide_banner -loglevel error' _
            & ' -i "' & $sDir & '\samples\tone500.wav" -i "' & $sDir & '\samples\tone1200.wav"' _
            & ' -filter_complex "[0]volume=0.8,adelay=500[a];[1]volume=0.5,adelay=1500[b];' _
            & '[a][b]amix=inputs=2:normalize=0,apad=whole_dur=2.5"' _
            & ' -ac 1 -ar 44100 -c:a pcm_s16le "' & $sDir & '\mix.wav""', "", @SW_HIDE)
    Assert(FileExists($sDir & "\mix.wav"), "génération mix")

    ; Lancement + poll
    Engine_Start($sDir & "\mix.wav", $sDir & "\samples", _
            $sDir & "\result.json", $sDir & "\result.tsv", _
            @ScriptDir & "\..\engine\analyze.py")
    Assert(Not @error, "Engine_Start (@error=" & @error & ")")

    Local $hTimeout = TimerInit()
    Local $iRes = 0
    While 1
        $iRes = Engine_Poll()
        If $iRes <> 0 Then ExitLoop
        If TimerDiff($hTimeout) > 120000 Then
            Engine_Cancel()
            ExitLoop
        EndIf
        Sleep(100)
    WEnd
    Assert($iRes = 1, "moteur terminé OK (res=" & $iRes & ", err=" & Engine_LastError() & ")")
    Assert($g_iEngineProgress = 100, "progression finale 100 (obtenu " & $g_iEngineProgress & ")")

    ; Parsing TSV
    Engine_LoadResults()
    Assert(Not @error, "Engine_LoadResults")
    Assert($g_iDetections = 2, "2 détections (obtenu " & $g_iDetections & ")")
    Local $bT500 = False, $bT1200 = False
    Local $i
    For $i = 0 To $g_iDetections - 1
        If $g_aDetections[$i][0] = "tone500.wav" And Abs($g_aDetections[$i][1] - 0.5) < 0.02 Then $bT500 = True
        If $g_aDetections[$i][0] = "tone1200.wav" And Abs($g_aDetections[$i][1] - 1.5) < 0.02 Then $bT1200 = True
    Next
    Assert($bT500, "tone500 @ 0.5 s")
    Assert($bT1200, "tone1200 @ 1.5 s")
    Assert($g_iUnknowns = 0, "aucun inconnu (obtenu " & $g_iUnknowns & ")")

    ; Annulation propre sur relance
    Engine_Start($sDir & "\mix.wav", $sDir & "\samples", _
            $sDir & "\result.json", $sDir & "\result.tsv", _
            @ScriptDir & "\..\engine\analyze.py")
    Assert(Not @error, "relance Engine_Start")
    Engine_Cancel()
    Assert(Not Engine_IsRunning(), "Engine_Cancel tue le processus")

    If $g_iFailures > 0 Then
        ConsoleWrite("FAIL : " & $g_iFailures & " échec(s)" & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS" & @CRLF)
    Exit 0
EndFunc

Func Assert($bCond, $sLabel)
    If $bCond Then
        ConsoleWrite("  ok  " & $sLabel & @CRLF)
    Else
        ConsoleWrite("  KO  " & $sLabel & @CRLF)
        $g_iFailures += 1
    EndIf
EndFunc
