; ===========================================================================
; Test phase 2 : extraction audio ffmpeg + lecture d'en-tête WAV.
; Lancement : AutoIt3.exe tests\Phase2Test.au3   (exit 0 = PASS)
; Génère 3 s de sinus 440 Hz en MP4 (AAC), extrait en PCM mono 44.1 kHz,
; vérifie durée et format via Wav_ReadInfo.
; ===========================================================================

#include "..\src\Ffmpeg.au3"
#include "..\src\Wav.au3"

Opt("MustDeclareVars", 1)

Global $g_iFailures = 0

Main()

Func Main()
    ; Ffmpeg_Locate cherche @ScriptDir\bin : ici tests\bin — on pointe la racine projet
    Local $sProjectBin = @ScriptDir & "\..\bin\ffmpeg.exe"
    If FileExists($sProjectBin) Then $g_sFfmpegPath = $sProjectBin
    Local $sFf = Ffmpeg_Locate()
    If $sFf = "" Then
        ConsoleWrite("SKIP : ffmpeg introuvable" & @CRLF)
        Exit 2
    EndIf

    Local $sDir = @TempDir & "\SampleTrackerTest"
    DirCreate($sDir)
    Local $sMp4 = $sDir & "\tone.mp4"
    Local $sWav = $sDir & "\out.wav"
    Local $sLog = $sDir & "\ffmpeg.log"

    ; Génération du fichier de test (3 s de sinus, AAC dans conteneur MP4)
    RunWait(@ComSpec & ' /c ""' & $sFf & '" -y -hide_banner -loglevel error' _
            & ' -f lavfi -i "sine=frequency=440:duration=3" -c:a aac "' & $sMp4 & '""', "", @SW_HIDE)
    Assert(FileExists($sMp4), "génération MP4 de test")

    ; Extraction asynchrone + attente
    Ffmpeg_StartExtract($sMp4, $sWav, $sLog)
    Assert(Not @error, "lancement extraction")
    Local $hTimeout = TimerInit()
    While Ffmpeg_IsRunning()
        If TimerDiff($hTimeout) > 30000 Then
            Ffmpeg_Cancel()
            Assert(False, "timeout extraction (30 s)")
            ExitLoop
        EndIf
        Sleep(100)
    WEnd

    ; Vérifications format + durée
    Local $iRate, $iChannels, $iBits
    Local $fDuration = Wav_ReadInfo($sWav, $iRate, $iChannels, $iBits)
    Assert(Not @error, "lecture en-tête WAV (@error=" & @error & ")")
    Assert($iRate = 44100, "samplerate 44100 (obtenu " & $iRate & ")")
    Assert($iChannels = 1, "mono (obtenu " & $iChannels & ")")
    Assert($iBits = 16, "16 bits (obtenu " & $iBits & ")")
    Assert(Abs($fDuration - 3) < 0.15, StringFormat("durée ~3 s (obtenu %.3f)", $fDuration))

    ; Erreur propre sur fichier invalide
    Local $sBad = $sDir & "\bad.mp4"
    FileDelete($sBad)
    FileWrite($sBad, "pas un mp4")
    Ffmpeg_StartExtract($sBad, $sDir & "\bad.wav", $sLog)
    $hTimeout = TimerInit()
    While Ffmpeg_IsRunning() And TimerDiff($hTimeout) < 15000
        Sleep(100)
    WEnd
    Local $fBad = Wav_ReadInfo($sDir & "\bad.wav", $iRate, $iChannels, $iBits)
    Assert(@error <> 0 Or $fBad = 0, "fichier invalide : pas de WAV produit")
    Assert(Ffmpeg_LastErrorLine() <> "", "ligne d'erreur ffmpeg disponible")

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
