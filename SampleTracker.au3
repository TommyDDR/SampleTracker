; ===========================================================================
; SampleTracker — analyse et décomposition audio (phase 1 : squelette GUI)
;
; Pipeline de rendu conforme à pratiques-rendu-performant.md :
;   - backbuffer DIB 32bpp + memory DC, composition GDI+
;   - un seul blit de présentation par frame (SRCCOPY)
;   - WM_ERASEBKGND intercepté (anti-scintillement)
;   - cache UI à clé scalaire, profiler F3, registre de disposers
; ===========================================================================

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <WinAPIGdi.au3>
#include <GDIPlus.au3>
#include <Misc.au3>
#include <File.au3>
#include <Array.au3>

#include "src\State.au3"
#include "src\Perf.au3"
#include "src\Render.au3"
#include "src\Engine.au3" ; avant Layout/Config : seuil de détection partagé
#include "src\Layout.au3"
#include "src\Config.au3"
#include "src\Player.au3"
#include "src\Ffmpeg.au3"
#include "src\Wav.au3"
#include "src\Waveform.au3"
#include "src\Timeline.au3"
#include "src\UiDraw.au3"
#include "src\Actions.au3"
#include "src\Drop.au3"

Opt("MustDeclareVars", 1)
Opt("GUIOnEventMode", 0)

Global Const $APP_FRAME_MS = 1000 / 300
Global $g_hNtdll = DllOpen("ntdll.dll")

Main()

Func Main()
    _GDIPlus_Startup()
    App_CreateWindow()
    ; Mode diagnostic : --shot <fichier.png> [--analyze]
    ; rend un état stabilisé, enregistre le backbuffer, puis quitte.
    If $CmdLine[0] >= 2 And $CmdLine[1] = "--shot" Then
        App_ShotMode($CmdLine[2], _App_HasArg("--analyze"))
        App_Shutdown()
        Return
    EndIf
    App_Loop()
    App_Shutdown()
EndFunc

Func _App_HasArg($sArg)
    Local $i
    For $i = 1 To $CmdLine[0]
        If $CmdLine[$i] = $sArg Then Return True
    Next
    Return False
EndFunc

; Fait tourner la boucle jusqu'à ce que tout soit prêt (extraction, waveform,
; analyse si demandée), puis enregistre le backbuffer.
Func App_ShotMode($sPath, $bAnalyze)
    Local $hTimeout = TimerInit()
    Local $bAnalyzeStarted = False
    While TimerDiff($hTimeout) < 120000
        App_HandleEvents()
        Action_PollExtraction()
        Action_PollEngine()
        Waveform_Step()
        Ui_DrawFrame()
        Render_Present()
        If $bAnalyze And Not $bAnalyzeStarted And App_IsAnalyzeReady() Then
            Action_Analyze()
            $bAnalyzeStarted = True
        EndIf
        Local $bReady = ($g_sSourceWav <> "" And $g_bWaveReady And Not $g_bExtracting)
        If $bAnalyze Then $bReady = $bReady And $bAnalyzeStarted And Not $g_bAnalyzing
        If $bReady Then ExitLoop
        Sleep(20)
    WEnd
    ; --played <nom> : simule la mise en évidence du dernier sample joué
    ; --hover <x> <y> : simule le survol (contrôle des infobulles)
    Local $i
    For $i = 1 To $CmdLine[0] - 1
        If $CmdLine[$i] = "--played" Then $g_sLastPlayed = $CmdLine[$i + 1]
        If $CmdLine[$i] = "--hover" And $i + 2 <= $CmdLine[0] Then
            App_UpdateHoverAt(Number($CmdLine[$i + 1]), Number($CmdLine[$i + 2]))
        EndIf
    Next
    Ui_InvalidateAll()
    Ui_Redraw() ; forcer un rendu complet, cache ignoré
    Render_Present()
    Render_SaveBackbuffer($sPath)
    ConsoleWrite((@error ? "echec capture" : "capture : " & $sPath) & @CRLF)
EndFunc

; --- Fenêtre ---------------------------------------------------------------

Func App_CreateWindow()
    $g_sWorkDir = @TempDir & "\SampleTracker"
    DirCreate($g_sWorkDir)
    Config_Load() ; géométrie, hauteurs de zones et dernière session
    $g_hGui = GUICreate("SampleTracker", $g_iWinW, $g_iWinH, $g_iWinX, $g_iWinY, _
            BitOR($WS_OVERLAPPEDWINDOW, $WS_CLIPCHILDREN))
    GUISetBkColor(0x17171C, $g_hGui)
    GUIRegisterMsg($WM_ERASEBKGND, "App_OnEraseBkgnd")
    GUIRegisterMsg(0x020A, "App_OnMouseWheel") ; WM_MOUSEWHEEL
    Drop_Startup($g_hGui)
    GUISetState($g_bWinMax ? @SW_MAXIMIZE : @SW_SHOW, $g_hGui)

    Local $aSize = WinGetClientSize($g_hGui)
    Render_Startup($g_hGui, $aSize[0], $aSize[1])
    Layout_Recompute($aSize[0], $aSize[1])
    Ui_Startup()
    Action_RestoreSession() ; recharge la dernière source / bibliothèque
EndFunc

; Anti-scintillement (doc rendu §2) : "déjà effacé", on repeint tout.
Func App_OnEraseBkgnd($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $wParam, $lParam
    Return 1
EndFunc

; --- Boucle principale (doc rendu §10) -------------------------------------

Func App_Loop()
    While $g_bRunning
        Local $hFrameTimer = TimerInit()

        Perf_Begin($PERF_INPUT)
        App_HandleEvents()
        App_HandlePerfKey()
        Action_PollExtraction() ; fin d'extraction ffmpeg (coût nul hors extraction)
        Action_PollEngine()     ; progression/fin du moteur d'analyse
        Waveform_Step()         ; calcul des pics par lots (coût nul hors calcul)
        Player_Poll()           ; position de lecture + fin de lecture
        Player_PollSample()     ; libère l'alias de prévisualisation
        App_ProcessWheel()
        App_UpdateDrag()
        Perf_End($PERF_INPUT)

        If Not BitAND(WinGetState($g_hGui), 16) Then ; pas minimisée
            Perf_Begin($PERF_UI)
            Ui_DrawFrame() ; redessine le backbuffer seulement si la clé change
            Perf_End($PERF_UI)

            Perf_Begin($PERF_PRESENT)
            Render_Present()
            Perf_End($PERF_PRESENT)
        EndIf

        Perf_FrameDone($hFrameTimer)
        App_SyncFrame($hFrameTimer)
    WEnd
EndFunc

Func App_HandleEvents()
    While 1
        Local $iMsg = GUIGetMsg()
        If $iMsg = 0 Then ExitLoop
        Switch $iMsg
            Case $GUI_EVENT_CLOSE
                $g_bRunning = False
            Case $GUI_EVENT_RESIZED, $GUI_EVENT_RESTORE, $GUI_EVENT_MAXIMIZE
                App_OnResize()
            Case $GUI_EVENT_MOUSEMOVE
                App_UpdateHover()
            Case $GUI_EVENT_PRIMARYDOWN
                App_OnPrimaryDown()
            Case $GUI_EVENT_SECONDARYDOWN
                App_OnSecondaryDown()
        EndSwitch
    WEnd
EndFunc

Func App_OnResize()
    Local $aSize = WinGetClientSize($g_hGui)
    If @error Then Return
    If $aSize[0] < 1 Or $aSize[1] < 1 Then Return
    If $aSize[0] = $g_iRenderW And $aSize[1] = $g_iRenderH Then Return
    Render_CreateTargets($aSize[0], $aSize[1])
    Layout_Recompute($aSize[0], $aSize[1])
    Ui_InvalidateAll() ; backbuffer neuf : caches UI invalidés
EndFunc

Func App_UpdateHover()
    Local $aInfo = GUIGetCursorInfo($g_hGui)
    If @error Then Return
    App_UpdateHoverAt($aInfo[0], $aInfo[1])
EndFunc

; Recalcule tout l'état de survol pour un point donné (séparé de la lecture
; de la souris : réutilisable pour le contrôle visuel en mode --shot).
Func App_UpdateHoverAt($iX, $iY)
    Local $iHit = Layout_HitButton($iX, $iY)
    If $iHit <> $g_iHoverButton Then $g_iHoverButton = $iHit
    ; Bloc timeline survolé (tooltip)
    Local $iBlock = -1
    If $g_iTlBlocks > 0 And Layout_PointInRect($iX, $iY, $g_aRectTlBlocks) Then
        Local $fViewStart, $fViewDur
        Ui_GetTimelineView($fViewStart, $fViewDur)
        $iBlock = Timeline_HitBlock($iX, $iY, $g_aRectTlBlocks, $fViewStart, $fViewDur)
    EndIf
    $g_iHoverBlock = $iBlock
    $g_iHoverX = $iX
    $g_iHoverY = $iY
    ; Réglette du seuil de détection
    $g_bHoverThreshold = $g_bThresholdDrag Or Layout_HitThreshold($iX, $iY)
    ; Sample survolé dans la bibliothèque
    $g_iHoverSample = Layout_HitSample($iX, $iY, UBound($g_aSampleFiles))
    $g_bSamplesMore = App_HitSamplesMore($iX, $iY)
    ; Libellé de piste survolé (infobulle avec le nom complet)
    $g_iHoverLane = -1
    If $g_iTlLanes > 0 And $g_iHoverBlock = -1 Then
        Local $iRowH, $iVisible
        Timeline_LayoutRows($g_aRectTlBlocks, $iRowH, $iVisible)
        $g_iHoverLane = Layout_HitLaneLabel($iX, $iY, $iVisible, $iRowH)
    EndIf
    ; Poignée de redimensionnement (prioritaire pour le choix du curseur)
    $g_iHoverSplitter = ($g_iDragSplitter <> $SPLIT_NONE) _
            ? $g_iDragSplitter : Layout_HitSplitter($iX, $iY)
    App_UpdateCursorForPoint($iX, $iY)
EndFunc

; Ligne « + N autres… » de la bibliothèque (au-dessus de la grille).
Func App_HitSamplesMore($iX, $iY)
    If Layout_SampleMaxScroll(UBound($g_aSampleFiles)) <= 0 Then Return False
    Return $iX >= $g_aRectSamplesList[0] And $iX < $g_aRectSamplesList[0] + $g_aRectSamplesList[2] _
            And $iY >= $g_aRectSamplesList[1] - 20 And $iY < $g_aRectSamplesList[1]
EndFunc

; Applique un curseur souris. Ne touche au curseur que sur changement
; d'état (pas d'appel Windows par frame).
Func App_SetCursor($iCursor)
    If $iCursor = $g_iCursorCurrent Then Return
    $g_iCursorCurrent = $iCursor
    GUISetCursor($iCursor, 0, $g_hGui)
EndFunc

; Choisit le curseur selon la zone survolée : poignée de redimensionnement,
; élément cliquable (waveform, timeline, libellés de pistes, boutons, samples),
; sinon flèche.
Func App_UpdateCursorForPoint($iX, $iY)
    If $g_iHoverSplitter <> $SPLIT_NONE Then
        App_SetCursor($CURSOR_SIZENS)
        Return
    EndIf
    Local $bClickable = ($g_iHoverButton <> -1) _
            Or ($g_iHoverSample >= 0) Or $g_bSamplesMore Or $g_bHoverThreshold _
            Or ($g_iHoverLane >= 0) _
            Or ($g_bWaveReady And Layout_PointInRect($iX, $iY, $g_aRectWave)) _
            Or ($g_iTlBlocks > 0 And Layout_PointInRect($iX, $iY, $g_aRectTlBlocks))
    App_SetCursor($bClickable ? $CURSOR_HAND : $CURSOR_ARROW)
EndFunc

; Accumule le delta molette (handler de message : rester minimal).
; Ctrl enfoncé (MK_CONTROL dans le low word) = zoom amplitude.
Func App_OnMouseWheel($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $lParam
    Local $iDelta = BitAND(BitShift($wParam, 16), 0xFFFF)
    If $iDelta > 32767 Then $iDelta -= 65536
    If BitAND($wParam, 0x0008) Then ; MK_CONTROL
        $g_iWheelDeltaCtrl += $iDelta
    Else
        $g_iWheelDelta += $iDelta
    EndIf
    Return 0
EndFunc

; Zoom autour du curseur (consommé chaque frame).
; Molette = zoom temporel (X), Ctrl+molette = zoom amplitude (Y).
Func App_ProcessWheel()
    If $g_iWheelDelta = 0 And $g_iWheelDeltaCtrl = 0 Then Return
    Local $iDelta = $g_iWheelDelta
    Local $iDeltaCtrl = $g_iWheelDeltaCtrl
    $g_iWheelDelta = 0
    $g_iWheelDeltaCtrl = 0
    Local $aInfo = GUIGetCursorInfo($g_hGui)
    If @error Then Return
    ; Molette sur la bibliothèque : défilement de la liste
    If Layout_PointInRect($aInfo[0], $aInfo[1], $g_aRectSamplesList) Then
        $g_iSamplesScroll -= Int(($iDelta + $iDeltaCtrl) / 120) * 3
        Layout_ClampSamplesScroll(UBound($g_aSampleFiles))
        Return
    EndIf
    If Not $g_bWaveReady Then Return
    ; Zoom X actif sur la waveform ET sur la zone de blocs timeline (vue partagée)
    Local $aRect = 0
    If Layout_PointInRect($aInfo[0], $aInfo[1], $g_aRectWave) Then
        $aRect = $g_aRectWave
    ElseIf $g_iTlBlocks > 0 And Layout_PointInRect($aInfo[0], $aInfo[1], $g_aRectTlBlocks) Then
        $aRect = $g_aRectTlBlocks
    Else
        Return
    EndIf
    If $iDelta <> 0 Then
        Local $fAnchor = $g_fViewStart + ($aInfo[0] - $aRect[0]) * $g_fViewDur / $aRect[2]
        Waveform_Zoom(0.8 ^ ($iDelta / 120), $fAnchor)
    EndIf
    ; Zoom amplitude : uniquement pertinent sur la waveform
    If $iDeltaCtrl <> 0 And Layout_PointInRect($aInfo[0], $aInfo[1], $g_aRectWave) Then _
            Waveform_ZoomY(1.25 ^ ($iDeltaCtrl / 120))
EndFunc

; Glisser en cours : redimensionnement d'une zone, scrub (bouton gauche) ou
; pan de la vue (bouton droit).
Func App_UpdateDrag()
    ; Redimensionnement des zones par poignée
    If $g_iDragSplitter <> $SPLIT_NONE Then
        Local $aSplit = GUIGetCursorInfo($g_hGui)
        If @error Then Return
        If $aSplit[2] = 0 Then
            $g_iDragSplitter = $SPLIT_NONE
            Return
        EndIf
        Layout_DragSplitter($g_iDragSplitter, $aSplit[1])
        Return
    EndIf

    Local $aInfo
    ; Réglette du seuil
    If $g_bThresholdDrag Then
        $aInfo = GUIGetCursorInfo($g_hGui)
        If @error Then Return
        If $aInfo[2] = 0 Then
            $g_bThresholdDrag = False
            Return
        EndIf
        Engine_SetThreshold(Layout_ThresholdFromX($aInfo[0]))
        Return
    EndIf

    ; Scrub : la tête de lecture suit la souris tant que le bouton est tenu
    If $g_bScrubDrag Then
        $aInfo = GUIGetCursorInfo($g_hGui)
        If @error Then Return
        If $aInfo[2] = 0 Then
            $g_bScrubDrag = False
            Player_ScrubEnd() ; seule commande MCI du glisser
            Return
        EndIf
        App_ScrubToX($aInfo[0])
        Return
    EndIf

    If Not $g_bWaveDragging Then Return
    $aInfo = GUIGetCursorInfo($g_hGui)
    If @error Then Return
    If $aInfo[3] = 0 Then ; bouton droit relâché
        $g_bWaveDragging = False
        Return
    EndIf
    Local $fNewStart = $g_fDragStartView - ($aInfo[0] - $g_iDragStartX) * $g_fViewDur / $g_iDragRefW
    Waveform_SetView($fNewStart, $g_fViewDur)
EndFunc

; Place la tête de lecture sous l'abscisse souris, dans l'échelle du rect où
; le glisser a démarré (waveform ou blocs timeline : même vue temporelle).
Func App_ScrubToX($iX)
    Local $fPos = $g_fViewStart + ($iX - $g_iScrubRefX) * $g_fViewDur / $g_iScrubRefW
    If $fPos < 0 Then $fPos = 0
    If $g_fSourceDuration > 0 And $fPos > $g_fSourceDuration Then $fPos = $g_fSourceDuration
    Player_ScrubTo($fPos)
EndFunc

; Bouton droit sur la waveform ou les blocs timeline : pan de la vue.
Func App_OnSecondaryDown()
    If Not $g_bWaveReady Then Return
    Local $aInfo = GUIGetCursorInfo($g_hGui)
    If @error Then Return
    Local $aRect = 0
    If Layout_PointInRect($aInfo[0], $aInfo[1], $g_aRectWave) Then
        $aRect = $g_aRectWave
    ElseIf $g_iTlBlocks > 0 And Layout_PointInRect($aInfo[0], $aInfo[1], $g_aRectTlBlocks) Then
        $aRect = $g_aRectTlBlocks
    Else
        Return
    EndIf
    $g_bWaveDragging = True
    $g_iDragStartX = $aInfo[0]
    $g_fDragStartView = $g_fViewStart
    $g_iDragRefW = $aRect[2]
EndFunc

Func App_OnPrimaryDown()
    Local $aInfo = GUIGetCursorInfo($g_hGui)
    If @error Then Return

    ; Poignée de redimensionnement (prioritaire sur tout le reste)
    Local $iSplit = Layout_HitSplitter($aInfo[0], $aInfo[1])
    If $iSplit <> $SPLIT_NONE Then
        $g_iDragSplitter = $iSplit
        Return
    EndIf

    ; Réglette du seuil : saisie immédiate, puis suivi de la souris
    If Layout_HitThreshold($aInfo[0], $aInfo[1]) Then
        $g_bThresholdDrag = True
        Engine_SetThreshold(Layout_ThresholdFromX($aInfo[0]))
        Return
    EndIf

    ; « + N autres… » : défile d'une page pour atteindre le reste de la liste
    If App_HitSamplesMore($aInfo[0], $aInfo[1]) Then
        Local $iCols, $iRows, $iColW, $iRowH2
        Layout_SampleGrid($iCols, $iRows, $iColW, $iRowH2)
        $g_iSamplesScroll += $iRows
        Layout_ClampSamplesScroll(UBound($g_aSampleFiles))
        Return
    EndIf

    ; Sample de la bibliothèque : prévisualisation
    Local $iSample = Layout_HitSample($aInfo[0], $aInfo[1], UBound($g_aSampleFiles))
    If $iSample >= 0 Then
        Action_PreviewSample($g_aSampleFiles[$iSample])
        Return
    EndIf

    ; Waveform / blocs timeline : double-clic = vue complète, sinon début de scrub
    Local $aRect = 0
    If $g_bWaveReady And Layout_PointInRect($aInfo[0], $aInfo[1], $g_aRectWave) Then
        $aRect = $g_aRectWave
    ElseIf $g_bWaveReady And $g_iTlBlocks > 0 And Layout_PointInRect($aInfo[0], $aInfo[1], $g_aRectTlBlocks) Then
        $aRect = $g_aRectTlBlocks
        ; Clic sur un bloc de détection : prévisualiser le sample correspondant
        If $g_iHoverBlock >= 0 And $g_iHoverBlock < $g_iTlBlocks _
                And $g_aTlBlocks[$g_iHoverBlock][3] = 0 Then _
                Action_PreviewSample($g_aTlBlocks[$g_iHoverBlock][6])
    ElseIf $g_iHoverLane >= 0 And $g_iHoverLane < $g_iTlLanes _
            And $g_aTlLaneKind[$g_iHoverLane] = 0 Then
        ; Clic sur un libellé de piste : même prévisualisation
        Action_PreviewSample($g_aTlLaneName[$g_iHoverLane])
        Return
    EndIf
    If IsArray($aRect) Then
        If $g_hLastClickTimer <> 0 And TimerDiff($g_hLastClickTimer) < 400 _
                And Abs($aInfo[0] - $g_iLastClickX) < 5 And Abs($aInfo[1] - $g_iLastClickY) < 5 Then
            Waveform_ResetView()
            $g_hLastClickTimer = 0
            Return
        EndIf
        $g_hLastClickTimer = TimerInit()
        $g_iLastClickX = $aInfo[0]
        $g_iLastClickY = $aInfo[1]
        ; Scrub : la tête de lecture saute au point cliqué puis suit la souris
        $g_bScrubDrag = True
        $g_iScrubRefX = $aRect[0]
        $g_iScrubRefW = $aRect[2]
        Player_ScrubBegin()
        App_ScrubToX($aInfo[0])
        Return
    EndIf
    Switch Layout_HitButton($aInfo[0], $aInfo[1])
        Case $BTN_OPEN_SOURCE
            Action_OpenSourceDialog()
        Case $BTN_OPEN_SAMPLES
            Action_OpenSamplesDialog()
        Case $BTN_ANALYZE
            Action_Analyze()
        Case $BTN_PLAY
            Player_TogglePlayPause()
        Case $BTN_STOP
            Player_Stop()
    EndSwitch
EndFunc

; Toggle profiler sur F3 (front montant, fenêtre active uniquement).
Func App_HandlePerfKey()
    Local $bDown = _IsPressed("72")
    If $bDown And Not $g_bPerfKeyDown And WinActive($g_hGui) Then
        $g_bPerfEnabled = Not $g_bPerfEnabled
        If Not $g_bPerfEnabled Then WinSetTitle($g_hGui, "", "SampleTracker")
        Perf_Reset()
    EndIf
    $g_bPerfKeyDown = $bDown
EndFunc

; Cadence : NtDelayExecution, précision sub-milliseconde (doc rendu §10).
Func App_SyncFrame($hFrameTimer)
    Local $fRemain = $APP_FRAME_MS - TimerDiff($hFrameTimer)
    If $fRemain <= 0 Then Return
    DllCall($g_hNtdll, "dword", "NtDelayExecution", "bool", False, "int64*", -Int($fRemain * 10000))
EndFunc

; --- Arrêt -----------------------------------------------------------------

Func App_Shutdown()
    Config_Save() ; avant GUIDelete : la géométrie doit encore être lisible
    Player_Shutdown()
    Ffmpeg_Cancel()
    Engine_Cancel()
    Render_RunDisposers()
    Render_Shutdown($g_hGui)
    _GDIPlus_Shutdown()
    DllClose($g_hNtdll)
    GUIDelete($g_hGui)
EndFunc
