; ===========================================================================
; Test phase 3 : calcul des pics waveform + mipmaps + vue.
; Lancement : AutoIt3.exe tests\Phase3Test.au3   (exit 0 = PASS)
; Génère 2 s de WAV (1 s silence + 1 s carré 440 Hz à ±0.5), calcule les pics
; de façon synchrone, vérifie les valeurs par zone et l'agrégation mipmap.
; ===========================================================================

#include "..\src\Ffmpeg.au3"
#include "..\src\Wav.au3"
#include "..\src\Waveform.au3"

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

    Local $sDir = @TempDir & "\SampleTrackerTest"
    DirCreate($sDir)
    Local $sWav = $sDir & "\wave3.wav"

    ; 1 s de silence puis 1 s de carré 440 Hz à ±0.5 (±16384 en int16)
    RunWait(@ComSpec & ' /c ""' & $sFf & '" -y -hide_banner -loglevel error' _
            & ' -f lavfi -i "aevalsrc=if(lt(t\,1)\,0\,if(gte(sin(2*PI*440*t)\,0)\,0.5\,-0.5)):s=44100:d=2"' _
            & ' -ac 1 -c:a pcm_s16le "' & $sWav & '""', "", @SW_HIDE)
    Assert(FileExists($sWav), "génération WAV de test")

    ; Calcul synchrone (boucle sur Waveform_Step)
    Waveform_Start($sWav)
    Assert(Not @error, "Waveform_Start")
    Local $iSteps = 0
    While $g_bWaveComputing And $iSteps < 10000
        Waveform_Step()
        $iSteps += 1
    WEnd
    Assert($g_bWaveReady, "calcul terminé (ready)")
    Assert(Waveform_Progress() = 100, "progression 100 %")
    Assert(Abs($g_fWaveDuration - 2) < 0.05, StringFormat("durée ~2 s (%.3f)", $g_fWaveDuration))
    Assert($g_iWaveBuckets = Int($g_fWaveDuration * $WAVE_BUCKETS_PER_SEC), _
            "nombre de buckets (" & $g_iWaveBuckets & ")")

    ; Zone silencieuse : bucket à 0.2 s
    Local $iB = Int(0.2 * $WAVE_BUCKETS_PER_SEC)
    Assert(Abs($g_aWaveMin[$iB]) < 200 And Abs($g_aWaveMax[$iB]) < 200, _
            "silence à 0.2 s (min=" & $g_aWaveMin[$iB] & " max=" & $g_aWaveMax[$iB] & ")")

    ; Zone carré : bucket à 1.5 s
    $iB = Int(1.5 * $WAVE_BUCKETS_PER_SEC)
    Assert($g_aWaveMax[$iB] > 10000, "carré max à 1.5 s (" & $g_aWaveMax[$iB] & ")")
    Assert($g_aWaveMin[$iB] < -10000, "carré min à 1.5 s (" & $g_aWaveMin[$iB] & ")")

    ; Mipmaps construits
    Assert($g_iWaveMipLevels > 1, "mipmaps construits (" & $g_iWaveMipLevels & " niveaux)")

    ; Agrégation par colonne : fenêtre silencieuse vs fenêtre carré
    Local $iMin, $iMax
    Waveform_GetColumnPeaks(0.1, 0.4, $iMin, $iMax)
    Assert(Abs($iMin) < 200 And Abs($iMax) < 200, _
            "agrégation zone silence (min=" & $iMin & " max=" & $iMax & ")")
    Waveform_GetColumnPeaks(1.2, 1.8, $iMin, $iMax)
    Assert($iMax > 10000 And $iMin < -10000, _
            "agrégation zone carré (min=" & $iMin & " max=" & $iMax & ")")
    ; Vue complète : les extrêmes du carré doivent remonter par les mipmaps
    Waveform_GetColumnPeaks(0, 2, $iMin, $iMax)
    Assert($iMax > 10000 And $iMin < -10000, _
            "agrégation vue complète (min=" & $iMin & " max=" & $iMax & ")")

    ; Vue : zoom + clamps
    Waveform_ResetView()
    Assert($g_fViewStart = 0 And Abs($g_fViewDur - $g_fWaveDuration) < 0.001, "vue initiale complète")
    Waveform_Zoom(0.5, 1.0)
    Assert(Abs($g_fViewDur - $g_fWaveDuration / 2) < 0.001, "zoom x2 sur la durée")
    Assert($g_fViewStart >= 0 And $g_fViewStart + $g_fViewDur <= $g_fWaveDuration + 0.001, "vue clampée")
    Waveform_SetView(-5, 0.5)
    Assert($g_fViewStart = 0, "clamp début négatif")
    Waveform_SetView(100, 0.5)
    Assert($g_fViewStart + $g_fViewDur <= $g_fWaveDuration + 0.001, "clamp fin au-delà de la durée")

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
