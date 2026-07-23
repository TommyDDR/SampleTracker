; ===========================================================================
; Test : préférences INI, poignées de redimensionnement, grille bibliothèque
; et lecture audio (Player.au3).
; Lancement : AutoIt3.exe tests\PrefsTest.au3   (exit 0 = PASS, 2 = SKIP)
; ===========================================================================

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>

#include "..\src\State.au3"
#include "..\src\Layout.au3"
#include "..\src\Config.au3"
#include "..\src\Player.au3"
#include "..\src\Ffmpeg.au3"

Opt("MustDeclareVars", 1)

Global $g_iFailures = 0

Main()

Func Main()
    ; --- Layout : clamp des hauteurs et poignées --------------------------
    Layout_Recompute(1280, 720)
    Assert($g_aRectSource[3] = $g_iLayoutSourceH, "hauteur zone source appliquée")
    Assert($g_aRectSamples[3] = $g_iLayoutSamplesH, "hauteur zone bibliothèque appliquée")
    Assert($g_aRectTimeline[3] >= $LAYOUT_TIMELINE_MIN_H, _
            "timeline garde sa hauteur minimale (" & $g_aRectTimeline[3] & ")")

    ; Poignée entre source et timeline : détectée sur la bande de saisie
    Local $iEdge = $g_aRectSource[1] + $g_aRectSource[3] + Int($LAYOUT_MARGIN / 2)
    Assert(Layout_HitSplitter(600, $iEdge) = $SPLIT_SOURCE, "poignée source détectée")
    Assert(Layout_HitSplitter(600, $iEdge + 40) = $SPLIT_NONE, "pas de poignée hors bande")
    Local $iEdge2 = $g_aRectSamples[1] - Int($LAYOUT_MARGIN / 2)
    Assert(Layout_HitSplitter(600, $iEdge2) = $SPLIT_SAMPLES, "poignée bibliothèque détectée")

    ; Glisser la poignée source vers le bas agrandit la zone source
    Local $iBefore = $g_iLayoutSourceH
    Layout_DragSplitter($SPLIT_SOURCE, $iEdge + 60)
    Assert($g_iLayoutSourceH > $iBefore, "glisser la poignée agrandit la source")
    Assert($g_aRectTimeline[3] >= $LAYOUT_TIMELINE_MIN_H, "timeline toujours au minimum garanti")

    ; Demande excessive : clampée, jamais de hauteur négative
    Layout_DragSplitter($SPLIT_SOURCE, 5000)
    Assert($g_aRectTimeline[3] >= $LAYOUT_TIMELINE_MIN_H, "clamp haut (timeline preservée)")
    Assert($g_aRectSamples[3] >= $LAYOUT_SAMPLES_MIN_H, "clamp haut (bibliothèque preservée)")
    Layout_DragSplitter($SPLIT_SOURCE, -5000)
    Assert($g_iLayoutSourceH >= $LAYOUT_SOURCE_MIN_H, "clamp bas (source au minimum)")

    ; --- Grille bibliothèque : le hit-test suit la géométrie de dessin ----
    ReDim $g_aSampleFiles[5]
    Local $i
    For $i = 0 To 4
        $g_aSampleFiles[$i] = "s" & $i & ".wav"
    Next
    ; hauteurs par défaut (les tests de poignée ci-dessus les ont modifiées)
    $g_iLayoutSourceH = $LAYOUT_SOURCE_DEFAULT_H
    $g_iLayoutSamplesH = $LAYOUT_SAMPLES_DEFAULT_H
    Layout_Recompute(1280, 720)
    Local $iCols, $iRows, $iColW, $iRowH
    Layout_SampleGrid($iCols, $iRows, $iColW, $iRowH)
    ; Remplissage par lignes : (ligne 0, colonne 1) = index 1
    $g_iSamplesScroll = 0
    Local $iHitX = $g_aRectSamplesList[0] + $iColW + 5
    Local $iHitY = $g_aRectSamplesList[1] + 5
    Assert(Layout_HitSample($iHitX, $iHitY, 5) = 1, "hit-test grille : index 1 (ligne 0, colonne 1)")
    Assert(Layout_HitSample($iHitX, $iHitY, 1) = -1, "hit-test au-delà du nombre de samples")
    Assert(Layout_HitSample(5, 5, 5) = -1, "hit-test hors de la grille")
    ; La barre de défilement n'est pas une case cliquable
    Assert(Layout_HitSample($g_aRectSamplesList[0] + $g_aRectSamplesList[2] - 3, $iHitY, 5) = -1, _
            "hit-test sur la barre de défilement")

    ; --- Défilement de la bibliothèque ------------------------------------
    Local $iBig = $iCols * ($iRows + 4) ; 4 lignes de trop
    ReDim $g_aSampleFiles[$iBig]
    For $i = 0 To $iBig - 1
        $g_aSampleFiles[$i] = "big" & $i & ".wav"
    Next
    Assert(Layout_SampleMaxScroll($iBig) = 4, _
            "défilement maximal = 4 lignes (obtenu " & Layout_SampleMaxScroll($iBig) & ")")
    Assert(Layout_SampleMaxScroll($iCols) = 0, "pas de défilement si tout tient")
    ; Après défilement d'une ligne, la première case correspond à la ligne 1
    $g_iSamplesScroll = 1
    Assert(Layout_HitSample($g_aRectSamplesList[0] + 5, $g_aRectSamplesList[1] + 5, $iBig) = $iCols, _
            "hit-test décalé par le défilement")
    $g_iSamplesScroll = 999
    Layout_ClampSamplesScroll($iBig)
    Assert($g_iSamplesScroll = 4, "défilement borné au maximum")
    $g_iSamplesScroll = -5
    Layout_ClampSamplesScroll($iBig)
    Assert($g_iSamplesScroll = 0, "défilement borné à zéro")

    ; --- Ajustement de la timeline en fin d'analyse -----------------------
    $g_iLayoutSourceH = $LAYOUT_SOURCE_DEFAULT_H
    $g_iLayoutSamplesH = $LAYOUT_SAMPLES_DEFAULT_H
    Layout_Recompute(1280, 720)
    Local $iSamplesBefore = $g_iLayoutSamplesH
    Layout_FitTimelineToLanes(3, 30) ; 3 pistes seulement
    Assert($g_iLayoutSamplesH > $iSamplesBefore, _
            "la bibliothèque récupère la place libérée par la timeline")
    Assert($g_aRectTimeline[3] >= 24 + 3 * 30, "la timeline garde la place de ses 3 pistes")
    ; Beaucoup de pistes : la bibliothèque ne descend pas sous son minimum
    Layout_FitTimelineToLanes(50, 30)
    Assert($g_iLayoutSamplesH >= $LAYOUT_SAMPLES_MIN_H, "bibliothèque jamais sous son minimum")

    ; --- Config : écriture puis relecture ---------------------------------
    Local $sIni = @TempDir & "\SampleTrackerPrefsTest.ini"
    FileDelete($sIni)
    $g_sIniPath = $sIni
    IniWrite($sIni, "window", "x", 120)
    IniWrite($sIni, "window", "y", 60)
    IniWrite($sIni, "window", "w", 1000)
    IniWrite($sIni, "window", "h", 650)
    IniWrite($sIni, "layout", "source_h", 260)
    IniWrite($sIni, "layout", "samples_h", 150)
    IniWrite($sIni, "session", "source", "C:\demo\mix.wav")
    IniWrite($sIni, "session", "samples", "C:\demo\samples")
    ; Config_Load recalcule $g_sIniPath : on le repointe juste après
    Config_Load()
    $g_sIniPath = $sIni
    _ReloadFrom($sIni)
    Assert($g_iWinX = 120 And $g_iWinY = 60, "position fenêtre relue")
    Assert($g_iWinW = 1000 And $g_iWinH = 650, "taille fenêtre relue")
    Assert($g_iLayoutSourceH = 260 And $g_iLayoutSamplesH = 150, "hauteurs de zones relues")
    Assert($g_sLastSource = "C:\demo\mix.wav", "dernière source relue")
    Assert($g_sLastSamples = "C:\demo\samples", "dernière bibliothèque relue")

    ; Taille aberrante : bornée au minimum
    IniWrite($sIni, "window", "w", 200)
    IniWrite($sIni, "window", "h", 100)
    _ReloadFrom($sIni)
    Assert($g_iWinW >= 900 And $g_iWinH >= 600, "taille fenêtre bornée au minimum")
    FileDelete($sIni)

    ; --- Player : lecture réelle d'un WAV ---------------------------------
    Local $sProjectBin = @ScriptDir & "\..\bin\ffmpeg.exe"
    If FileExists($sProjectBin) Then $g_sFfmpegPath = $sProjectBin
    Local $sFf = Ffmpeg_Locate()
    If $sFf = "" Then
        ConsoleWrite("  --  ffmpeg absent : test Player sauté" & @CRLF)
    Else
        Local $sDir = @TempDir & "\SampleTrackerPrefsTest"
        DirCreate($sDir)
        Local $sWav = $sDir & "\tone.wav"
        RunWait(@ComSpec & ' /c ""' & $sFf & '" -y -hide_banner -loglevel error' _
                & ' -f lavfi -i "sine=frequency=440:duration=2" -ac 1 -ar 44100' _
                & ' -c:a pcm_s16le "' & $sWav & '""', "", @SW_HIDE)
        Player_OpenSource($sWav)
        Assert(Not @error And $g_bSrcOpen, "Player_OpenSource")
        Player_SetCursor(0.5)
        Assert($g_fPlayCursor = 0.5, "curseur positionné à 0.5 s")
        Player_Play()
        Assert($g_bSrcPlaying, "lecture démarrée")
        Sleep(400)
        Player_Poll()
        Assert($g_fPlayPos > 0.5, "position avance (" & Round($g_fPlayPos, 3) & ")")
        Player_Pause()
        Assert(Not $g_bSrcPlaying And $g_bSrcPaused, "pause")
        Player_Play()
        Assert($g_bSrcPlaying, "reprise après pause")
        Player_Stop()
        Assert(Not $g_bSrcPlaying, "stop")
        Assert(Player_Position() = 0.5, "stop revient au curseur")
        Player_PlaySample($sWav)
        Assert($g_sSmpPlaying = $sWav, "prévisualisation d'un sample")
        Player_StopSample()
        Assert($g_sSmpPlaying = "", "arrêt de la prévisualisation")
        Player_Shutdown()
        Assert(Not $g_bSrcOpen, "Player_Shutdown")
        DirRemove($sDir, 1)
    EndIf

    If $g_iFailures > 0 Then
        ConsoleWrite("FAIL : " & $g_iFailures & " échec(s)" & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS" & @CRLF)
    Exit 0
EndFunc

; Relit les préférences depuis un INI précis (Config_Load vise @ScriptDir).
Func _ReloadFrom($sIni)
    $g_iWinX = Int(IniRead($sIni, "window", "x", -1))
    $g_iWinY = Int(IniRead($sIni, "window", "y", -1))
    $g_iWinW = Int(IniRead($sIni, "window", "w", 1280))
    $g_iWinH = Int(IniRead($sIni, "window", "h", 720))
    If $g_iWinW < 900 Then $g_iWinW = 900
    If $g_iWinH < 600 Then $g_iWinH = 600
    $g_iLayoutSourceH = Int(IniRead($sIni, "layout", "source_h", $LAYOUT_SOURCE_DEFAULT_H))
    $g_iLayoutSamplesH = Int(IniRead($sIni, "layout", "samples_h", $LAYOUT_SAMPLES_DEFAULT_H))
    Layout_ClampHeights()
    $g_sLastSource = IniRead($sIni, "session", "source", "")
    $g_sLastSamples = IniRead($sIni, "session", "samples", "")
EndFunc

Func Assert($bCond, $sLabel)
    If $bCond Then
        ConsoleWrite("  ok  " & $sLabel & @CRLF)
    Else
        ConsoleWrite("  KO  " & $sLabel & @CRLF)
        $g_iFailures += 1
    EndIf
EndFunc
