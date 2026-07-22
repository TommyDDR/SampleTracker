#include-once

; ---------------------------------------------------------------------------
; Dessin de l'interface (thème sombre type DAW).
; Cache à clé plein écran (doc rendu §7.3) : le backbuffer n'est redessiné
; que si la clé scalaire change ; Render_Present() est appelé chaque frame.
; ---------------------------------------------------------------------------

; Couleurs (ARGB)
Global Const $UI_COLOR_BG = 0xFF17171C
Global Const $UI_COLOR_TOPBAR = 0xFF20202A
Global Const $UI_COLOR_PANEL = 0xFF232329
Global Const $UI_COLOR_BORDER = 0xFF34343E
Global Const $UI_COLOR_TEXT = 0xFFE2E2E8
Global Const $UI_COLOR_MUTED = 0xFF8A8A98
Global Const $UI_COLOR_TEXT_DISABLED = 0xFF55555F
Global Const $UI_COLOR_ACCENT = 0xFF4FA8E8
Global Const $UI_COLOR_OK = 0xFF58C878
Global Const $UI_COLOR_ERROR = 0xFFE06060
Global Const $UI_COLOR_BUTTON = 0xFF32323E
Global Const $UI_COLOR_BUTTON_HOVER = 0xFF3E3E4E
Global Const $UI_COLOR_BUTTON_DISABLED = 0xFF26262E
Global Const $UI_COLOR_ANALYZE = 0xFF2F6E49
Global Const $UI_COLOR_ANALYZE_HOVER = 0xFF388055
Global Const $UI_COLOR_WAVE_BG = 0xFF1B1B21
Global Const $UI_COLOR_WAVE_LINE = 0xFF3A3A46

Global Const $UI_STATUS_TIMEOUT_MS = 8000
Global Const $UI_GDIP_NOWRAP = 0x1000

; Ressources GDI+ partagées (créées au démarrage, jamais par frame — doc §8)
Global $g_hFamilyUi = 0
Global $g_hFontTitle = 0
Global $g_hFontNormal = 0
Global $g_hFontSmall = 0
Global $g_hFontZone = 0
Global $g_hBrushText = 0
Global $g_hBrushMuted = 0
Global $g_hBrushTextDisabled = 0
Global $g_hBrushAccent = 0
Global $g_hBrushOk = 0
Global $g_hBrushError = 0
Global $g_hBrushPanel = 0
Global $g_hBrushTopBar = 0
Global $g_hBrushButton = 0
Global $g_hBrushButtonHover = 0
Global $g_hBrushButtonDisabled = 0
Global $g_hBrushAnalyze = 0
Global $g_hBrushAnalyzeHover = 0
Global $g_hBrushWaveBg = 0
Global $g_hPenBorder = 0
Global $g_hPenWaveLine = 0
Global $g_hPenWave = 0
Global $g_hPenRuler = 0
Global $g_hFmtLeft = 0
Global $g_hFmtCenter = 0
Global $g_hFmtRight = 0
Global $g_hFmtCenterWrap = 0

Func Ui_Startup()
    $g_hFamilyUi = _GDIPlus_FontFamilyCreate("Segoe UI")
    If @error Or $g_hFamilyUi = 0 Then $g_hFamilyUi = _GDIPlus_FontFamilyCreate("Arial")

    $g_hFontTitle = _GDIPlus_FontCreate($g_hFamilyUi, 17, 1)
    $g_hFontNormal = _GDIPlus_FontCreate($g_hFamilyUi, 12, 0)
    $g_hFontSmall = _GDIPlus_FontCreate($g_hFamilyUi, 10, 0)
    $g_hFontZone = _GDIPlus_FontCreate($g_hFamilyUi, 10, 1)

    $g_hBrushText = _GDIPlus_BrushCreateSolid($UI_COLOR_TEXT)
    $g_hBrushMuted = _GDIPlus_BrushCreateSolid($UI_COLOR_MUTED)
    $g_hBrushTextDisabled = _GDIPlus_BrushCreateSolid($UI_COLOR_TEXT_DISABLED)
    $g_hBrushAccent = _GDIPlus_BrushCreateSolid($UI_COLOR_ACCENT)
    $g_hBrushOk = _GDIPlus_BrushCreateSolid($UI_COLOR_OK)
    $g_hBrushError = _GDIPlus_BrushCreateSolid($UI_COLOR_ERROR)
    $g_hBrushPanel = _GDIPlus_BrushCreateSolid($UI_COLOR_PANEL)
    $g_hBrushTopBar = _GDIPlus_BrushCreateSolid($UI_COLOR_TOPBAR)
    $g_hBrushButton = _GDIPlus_BrushCreateSolid($UI_COLOR_BUTTON)
    $g_hBrushButtonHover = _GDIPlus_BrushCreateSolid($UI_COLOR_BUTTON_HOVER)
    $g_hBrushButtonDisabled = _GDIPlus_BrushCreateSolid($UI_COLOR_BUTTON_DISABLED)
    $g_hBrushAnalyze = _GDIPlus_BrushCreateSolid($UI_COLOR_ANALYZE)
    $g_hBrushAnalyzeHover = _GDIPlus_BrushCreateSolid($UI_COLOR_ANALYZE_HOVER)
    $g_hBrushWaveBg = _GDIPlus_BrushCreateSolid($UI_COLOR_WAVE_BG)

    $g_hPenBorder = _GDIPlus_PenCreate($UI_COLOR_BORDER, 1)
    $g_hPenWaveLine = _GDIPlus_PenCreate($UI_COLOR_WAVE_LINE, 1)
    $g_hPenWave = _GDIPlus_PenCreate($UI_COLOR_ACCENT, 1)
    $g_hPenRuler = _GDIPlus_PenCreate($UI_COLOR_MUTED, 1)

    $g_hFmtLeft = _GDIPlus_StringFormatCreate($UI_GDIP_NOWRAP)
    _GDIPlus_StringFormatSetAlign($g_hFmtLeft, 0)
    _GDIPlus_StringFormatSetLineAlign($g_hFmtLeft, 1)

    $g_hFmtCenter = _GDIPlus_StringFormatCreate($UI_GDIP_NOWRAP)
    _GDIPlus_StringFormatSetAlign($g_hFmtCenter, 1)
    _GDIPlus_StringFormatSetLineAlign($g_hFmtCenter, 1)

    $g_hFmtRight = _GDIPlus_StringFormatCreate($UI_GDIP_NOWRAP)
    _GDIPlus_StringFormatSetAlign($g_hFmtRight, 2)
    _GDIPlus_StringFormatSetLineAlign($g_hFmtRight, 1)

    $g_hFmtCenterWrap = _GDIPlus_StringFormatCreate()
    _GDIPlus_StringFormatSetAlign($g_hFmtCenterWrap, 1)
    _GDIPlus_StringFormatSetLineAlign($g_hFmtCenterWrap, 1)

    Render_RegisterDisposer("Ui_Dispose")
EndFunc

; --- Cache à clé -----------------------------------------------------------

Func Ui_SetStatus($sText, $iKind = 0)
    $g_sStatusText = $sText
    $g_iStatusKind = $iKind
    $g_hStatusTimer = TimerInit()
EndFunc

Func Ui_IsStatusVisible()
    If $g_sStatusText = "" Then Return False
    Return TimerDiff($g_hStatusTimer) < $UI_STATUS_TIMEOUT_MS
EndFunc

; Clé bon marché : concat de scalaires déjà en mémoire (doc §7.3).
Func Ui_BuildCacheKey()
    Local $sStatus = ""
    If Ui_IsStatusVisible() Then $sStatus = $g_iStatusKind & ":" & $g_sStatusText
    ; Phase des points animés pendant l'extraction (change ~2x/s)
    Local $iExtractPhase = -1
    If $g_bExtracting Then $iExtractPhase = Mod(Int(TimerDiff($g_hExtractTimer) / 400), 4)
    Return $g_iRenderW & "|" & $g_iRenderH & "|" & $g_iHoverButton & "|" _
            & $g_sSourcePath & "|" & $g_sSourceWav & "|" & $g_fSourceDuration & "|" & $iExtractPhase & "|" _
            & $g_iWaveVersion & "|" & Waveform_Progress() & "|" & $g_fViewStart & "|" & $g_fViewDur & "|" _
            & $g_fWaveYZoom & "|" _
            & $g_sSamplesDir & "|" & UBound($g_aSampleFiles) & "|" _
            & (App_IsAnalyzeReady() ? 1 : 0) & "|" & $sStatus
EndFunc

Func Ui_DrawFrame()
    Local $sKey = Ui_BuildCacheKey()
    If $sKey = $g_sUiCacheKey Then Return
    $g_sUiCacheKey = $sKey
    Ui_Redraw()
EndFunc

; --- Dessin ----------------------------------------------------------------

Func Ui_Redraw()
    _GDIPlus_GraphicsClear($g_hGfx, $UI_COLOR_BG)
    Ui_DrawTopBar()
    Ui_DrawSourceZone()
    Ui_DrawTimelineZone()
    Ui_DrawSamplesZone()
    Ui_DrawStatusBar()
EndFunc

Func Ui_DrawTopBar()
    Local $aR = $g_aRectTopBar
    _GDIPlus_GraphicsFillRect($g_hGfx, $aR[0], $aR[1], $aR[2], $aR[3], $g_hBrushTopBar)
    _GDIPlus_GraphicsDrawLine($g_hGfx, $aR[0], $aR[3] - 1, $aR[0] + $aR[2], $aR[3] - 1, $g_hPenBorder)
    Ui_DrawText("SampleTracker", $g_hFontTitle, 16, 0, 300, $aR[3], $g_hBrushText, $g_hFmtLeft)
    Local $i
    For $i = 0 To $BTN_COUNT - 1
        Ui_DrawButton($i)
    Next
EndFunc

Func Ui_DrawButton($iIndex)
    Local $iX = $g_aRectButtons[$iIndex][0]
    Local $iY = $g_aRectButtons[$iIndex][1]
    Local $iW = $g_aRectButtons[$iIndex][2]
    Local $iH = $g_aRectButtons[$iIndex][3]
    Local $bEnabled = ($iIndex <> $BTN_ANALYZE) Or App_IsAnalyzeReady()
    Local $hFill = $g_hBrushButton
    Local $hText = $g_hBrushText
    If Not $bEnabled Then
        $hFill = $g_hBrushButtonDisabled
        $hText = $g_hBrushTextDisabled
    ElseIf $iIndex = $BTN_ANALYZE Then
        $hFill = ($g_iHoverButton = $iIndex) ? $g_hBrushAnalyzeHover : $g_hBrushAnalyze
    ElseIf $g_iHoverButton = $iIndex Then
        $hFill = $g_hBrushButtonHover
    EndIf
    _GDIPlus_GraphicsFillRect($g_hGfx, $iX, $iY, $iW, $iH, $hFill)
    _GDIPlus_GraphicsDrawRect($g_hGfx, $iX, $iY, $iW - 1, $iH - 1, $g_hPenBorder)
    Ui_DrawText($g_aButtonLabels[$iIndex], $g_hFontSmall, $iX, $iY, $iW, $iH, $hText, $g_hFmtCenter)
EndFunc

Func Ui_DrawSourceZone()
    Local $aR = $g_aRectSource
    Ui_DrawPanel($aR)
    Ui_DrawText("SOURCE", $g_hFontZone, $aR[0] + 14, $aR[1] + 4, 200, 20, $g_hBrushMuted, $g_hFmtLeft)
    If $g_sSourcePath = "" Then
        Ui_DrawText("Glisser un fichier MP3 / WAV / MP4 ici, ou utiliser « Ouvrir source »", _
                $g_hFontNormal, $aR[0], $aR[1], $aR[2], $aR[3], $g_hBrushMuted, $g_hFmtCenterWrap)
        Return
    EndIf
    Ui_DrawText(Action_FileName($g_sSourcePath), $g_hFontNormal, _
            $aR[0] + 14, $aR[1] + 24, $aR[2] - 28, 22, $g_hBrushAccent, $g_hFmtLeft)
    ; Ligne d'état : extraction en cours / infos PCM / chemin
    Local $sInfo = Ui_EllipsizePath($g_sSourcePath, 110)
    Local $hInfoBrush = $g_hBrushMuted
    If $g_bExtracting Then
        Local $iDots = Mod(Int(TimerDiff($g_hExtractTimer) / 400), 4)
        $sInfo = "Extraction audio en cours" & StringLeft("...", $iDots)
        $hInfoBrush = $g_hBrushAccent
    ElseIf $g_sSourceWav <> "" Then
        $sInfo = StringFormat("Durée : %.2f s — PCM %.1f kHz mono 16 bits — %s", _
                $g_fSourceDuration, $g_iSourceRate / 1000, Ui_EllipsizePath($g_sSourcePath, 70))
    EndIf
    Ui_DrawText($sInfo, $g_hFontSmall, _
            $aR[0] + 14, $aR[1] + 46, $aR[2] - 28, 16, $hInfoBrush, $g_hFmtLeft)
    ; Bande waveform : règle + pics
    Ui_DrawWaveform()
EndFunc

Func Ui_DrawWaveform()
    Local $aR = $g_aRectWave
    If $aR[3] < 24 Then Return
    _GDIPlus_GraphicsFillRect($g_hGfx, $aR[0], $aR[1], $aR[2], $aR[3], $g_hBrushWaveBg)
    _GDIPlus_GraphicsDrawRect($g_hGfx, $aR[0], $aR[1], $aR[2] - 1, $aR[3] - 1, $g_hPenBorder)

    If $g_bWaveComputing Then
        Ui_DrawText("Calcul de la waveform… " & Waveform_Progress() & " %", $g_hFontSmall, _
                $aR[0], $aR[1], $aR[2], $aR[3], $g_hBrushAccent, $g_hFmtCenter)
        Return
    EndIf
    If Not $g_bWaveReady Then
        _GDIPlus_GraphicsDrawLine($g_hGfx, $aR[0], $aR[1] + $aR[3] / 2, _
                $aR[0] + $aR[2], $aR[1] + $aR[3] / 2, $g_hPenWaveLine)
        Return
    EndIf

    Local $iRulerH = 18
    Local $iWaveY = $aR[1] + $iRulerH
    Local $iWaveH = $aR[3] - $iRulerH
    Local $fMid = $iWaveY + $iWaveH / 2
    Local $fHalf = $iWaveH / 2 - 2
    _GDIPlus_GraphicsDrawLine($g_hGfx, $aR[0], $fMid, $aR[0] + $aR[2], $fMid, $g_hPenWaveLine)

    Local $fSecPerPx = $g_fViewDur / $aR[2]
    Local $fScale = $fHalf * $g_fWaveYZoom / 32768
    Local $iClipTop = $iWaveY + 1
    Local $iClipBottom = $iWaveY + $iWaveH - 2
    Local $fBucketDur = Waveform_GetBucketDur()

    If $fBucketDur > 0 And $fSecPerPx < $fBucketDur Then
        ; Zoom fort : moins d'un bucket par colonne — tracé en polylignes
        ; fines (enveloppes min et max reliées entre buckets), jamais de
        ; colonnes pleines. Antialiasing temporaire (doc rendu §3).
        Local $i0 = Int($g_fViewStart / $fBucketDur) - 1
        Local $i1 = Int(($g_fViewStart + $g_fViewDur) / $fBucketDur) + 1
        If $i0 < 0 Then $i0 = 0
        If $i1 > $g_iWaveBuckets - 1 Then $i1 = $g_iWaveBuckets - 1
        _GDIPlus_GraphicsSetSmoothingMode($g_hGfx, 2)
        Local $i, $fX, $iYMin, $iYMax
        Local $fPrevX = 0, $iPrevYMin = 0, $iPrevYMax = 0, $bPrev = False
        For $i = $i0 To $i1
            $fX = $aR[0] + (($i + 0.5) * $fBucketDur - $g_fViewStart) / $fSecPerPx
            $iYMax = Int($fMid - $g_aWaveMax[$i] * $fScale)
            $iYMin = Int($fMid - $g_aWaveMin[$i] * $fScale)
            If $iYMax < $iClipTop Then $iYMax = $iClipTop
            If $iYMax > $iClipBottom Then $iYMax = $iClipBottom
            If $iYMin < $iClipTop Then $iYMin = $iClipTop
            If $iYMin > $iClipBottom Then $iYMin = $iClipBottom
            If $bPrev Then
                _GDIPlus_GraphicsDrawLine($g_hGfx, $fPrevX, $iPrevYMax, $fX, $iYMax, $g_hPenWave)
                If $iYMin <> $iYMax Or $iPrevYMin <> $iPrevYMax Then _
                        _GDIPlus_GraphicsDrawLine($g_hGfx, $fPrevX, $iPrevYMin, $fX, $iYMin, $g_hPenWave)
            EndIf
            $fPrevX = $fX
            $iPrevYMin = $iYMin
            $iPrevYMax = $iYMax
            $bPrev = True
        Next
        _GDIPlus_GraphicsSetSmoothingMode($g_hGfx, 0) ; restaurer (doc rendu §3)
    Else
        ; Une ligne verticale min/max par colonne de pixels
        Local $x, $iMin, $iMax, $iY1, $iY2
        For $x = 0 To $aR[2] - 1
            Waveform_GetColumnPeaks($g_fViewStart + $x * $fSecPerPx, _
                    $g_fViewStart + ($x + 1) * $fSecPerPx, $iMin, $iMax)
            $iY1 = Int($fMid - $iMax * $fScale)
            $iY2 = Int($fMid - $iMin * $fScale)
            If $iY1 < $iClipTop Then $iY1 = $iClipTop
            If $iY2 > $iClipBottom Then $iY2 = $iClipBottom
            If $iY2 - $iY1 < 1 Then $iY2 = $iY1 + 1
            _GDIPlus_GraphicsDrawLine($g_hGfx, $aR[0] + $x, $iY1, $aR[0] + $x, $iY2, $g_hPenWave)
        Next
    EndIf

    Ui_DrawRuler($aR[0], $aR[1], $aR[2], $iRulerH)
    ; Indicateur de zoom amplitude
    If $g_fWaveYZoom > 1 Then
        Ui_DrawText(StringFormat("Y ×%.1f", $g_fWaveYZoom), $g_hFontSmall, _
                $aR[0], $aR[1] + $iRulerH + 2, $aR[2] - 6, 14, $g_hBrushMuted, $g_hFmtRight)
    EndIf
EndFunc

; Règle temporelle : pas adaptatif (1/2/5), libellés m:ss ou m:ss.cc.
Func Ui_DrawRuler($iX, $iY, $iW, $iH)
    Local $aSteps[16] = [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600]
    Local $fPxPerSec = $iW / $g_fViewDur
    Local $fStep = $aSteps[15]
    Local $i
    For $i = 0 To 15
        If $aSteps[$i] * $fPxPerSec >= 70 Then
            $fStep = $aSteps[$i]
            ExitLoop
        EndIf
    Next
    Local $bFine = $fStep < 1
    Local $fT = Ceiling($g_fViewStart / $fStep) * $fStep
    Local $iPx
    While $fT <= $g_fViewStart + $g_fViewDur
        $iPx = $iX + Int(($fT - $g_fViewStart) * $fPxPerSec)
        If $iPx >= $iX And $iPx < $iX + $iW Then
            _GDIPlus_GraphicsDrawLine($g_hGfx, $iPx, $iY + $iH - 5, $iPx, $iY + $iH, $g_hPenRuler)
            Ui_DrawText(Ui_FormatTime($fT, $bFine), $g_hFontSmall, $iPx + 3, $iY, 80, $iH - 4, _
                    $g_hBrushMuted, $g_hFmtLeft)
        EndIf
        $fT += $fStep
    WEnd
EndFunc

Func Ui_FormatTime($fSec, $bFine)
    Local $iMin = Int($fSec / 60)
    Local $fS = $fSec - $iMin * 60
    If $bFine Then Return StringFormat("%d:%05.2f", $iMin, $fS)
    Return StringFormat("%d:%02d", $iMin, Int($fS + 0.5))
EndFunc

Func Ui_DrawTimelineZone()
    Local $aR = $g_aRectTimeline
    Ui_DrawPanel($aR)
    Ui_DrawText("TIMELINE", $g_hFontZone, $aR[0] + 14, $aR[1] + 4, 200, 20, $g_hBrushMuted, $g_hFmtLeft)
    Ui_DrawText("Les pistes et blocs de détection s'afficheront ici (phases 3 à 6)", _
            $g_hFontNormal, $aR[0], $aR[1], $aR[2], $aR[3], $g_hBrushMuted, $g_hFmtCenterWrap)
EndFunc

Func Ui_DrawSamplesZone()
    Local $aR = $g_aRectSamples
    Ui_DrawPanel($aR)
    Ui_DrawText("BIBLIOTHÈQUE DE SAMPLES", $g_hFontZone, $aR[0] + 14, $aR[1] + 4, 300, 20, $g_hBrushMuted, $g_hFmtLeft)
    Local $iCount = UBound($g_aSampleFiles)
    If $iCount = 0 Then
        Ui_DrawText("Glisser un dossier de samples ici, ou utiliser « Dossier samples »", _
                $g_hFontNormal, $aR[0], $aR[1], $aR[2], $aR[3], $g_hBrushMuted, $g_hFmtCenterWrap)
        Return
    EndIf
    Ui_DrawText($iCount & " samples", $g_hFontSmall, $aR[0], $aR[1] + 4, $aR[2] - 14, 20, $g_hBrushOk, $g_hFmtRight)
    Ui_DrawText(Ui_EllipsizePath($g_sSamplesDir, 110), $g_hFontSmall, _
            $aR[0] + 14, $aR[1] + 26, $aR[2] - 28, 16, $g_hBrushMuted, $g_hFmtLeft)

    ; Grille de noms (colonnes puis lignes)
    Local $iInnerX = $aR[0] + 14
    Local $iInnerY = $aR[1] + 48
    Local $iInnerW = $aR[2] - 28
    Local $iInnerH = $aR[1] + $aR[3] - 10 - $iInnerY
    Local $iColW = 240
    Local $iRowH = 20
    Local $iCols = Int($iInnerW / $iColW)
    If $iCols < 1 Then $iCols = 1
    Local $iRows = Int($iInnerH / $iRowH)
    If $iRows < 1 Then $iRows = 1
    Local $iMax = $iCols * $iRows
    Local $iShown = $iCount
    If $iCount > $iMax Then $iShown = $iMax - 1 ; réserver une case pour "+ N autres"
    Local $i, $iCol, $iRow
    For $i = 0 To $iShown - 1
        $iCol = Int($i / $iRows)
        $iRow = Mod($i, $iRows)
        Ui_DrawText("• " & Ui_EllipsizeEnd($g_aSampleFiles[$i], 32), $g_hFontSmall, _
                $iInnerX + $iCol * $iColW, $iInnerY + $iRow * $iRowH, $iColW - 10, $iRowH, _
                $g_hBrushText, $g_hFmtLeft)
    Next
    If $iCount > $iShown Then
        $iCol = Int($iShown / $iRows)
        $iRow = Mod($iShown, $iRows)
        Ui_DrawText("+ " & ($iCount - $iShown) & " autres…", $g_hFontSmall, _
                $iInnerX + $iCol * $iColW, $iInnerY + $iRow * $iRowH, $iColW - 10, $iRowH, _
                $g_hBrushMuted, $g_hFmtLeft)
    EndIf
EndFunc

Func Ui_DrawStatusBar()
    Local $aR = $g_aRectStatus
    Ui_DrawText("F3 : profiler", $g_hFontSmall, $aR[0], $aR[1], $aR[2] - 12, $aR[3], $g_hBrushMuted, $g_hFmtRight)
    If Not Ui_IsStatusVisible() Then Return
    Local $hBrush = $g_hBrushText
    If $g_iStatusKind = 1 Then $hBrush = $g_hBrushOk
    If $g_iStatusKind = 2 Then $hBrush = $g_hBrushError
    Ui_DrawText("● " & $g_sStatusText, $g_hFontSmall, $aR[0] + 12, $aR[1], $aR[2] - 160, $aR[3], $hBrush, $g_hFmtLeft)
EndFunc

; --- Helpers ---------------------------------------------------------------

Func Ui_DrawPanel($aRect)
    _GDIPlus_GraphicsFillRect($g_hGfx, $aRect[0], $aRect[1], $aRect[2], $aRect[3], $g_hBrushPanel)
    _GDIPlus_GraphicsDrawRect($g_hGfx, $aRect[0], $aRect[1], $aRect[2] - 1, $aRect[3] - 1, $g_hPenBorder)
EndFunc

Func Ui_DrawText($sText, $hFont, $iX, $iY, $iW, $iH, $hBrush, $hFormat)
    Local $tRect = _GDIPlus_RectFCreate($iX, $iY, $iW, $iH)
    _GDIPlus_GraphicsDrawStringEx($g_hGfx, $sText, $hFont, $tRect, $hFormat, $hBrush)
EndFunc

; Coupe la fin ("nom-tres-long…")
Func Ui_EllipsizeEnd($sText, $iMax)
    If StringLen($sText) <= $iMax Then Return $sText
    Return StringLeft($sText, $iMax - 1) & "…"
EndFunc

; Garde la fin ("…\dossier\fichier.mp3")
Func Ui_EllipsizePath($sText, $iMax)
    If StringLen($sText) <= $iMax Then Return $sText
    Return "…" & StringRight($sText, $iMax - 1)
EndFunc

; --- Disposer (registre §11, idempotent) -----------------------------------

Func Ui_Dispose()
    If $g_hFontTitle <> 0 Then _GDIPlus_FontDispose($g_hFontTitle)
    If $g_hFontNormal <> 0 Then _GDIPlus_FontDispose($g_hFontNormal)
    If $g_hFontSmall <> 0 Then _GDIPlus_FontDispose($g_hFontSmall)
    If $g_hFontZone <> 0 Then _GDIPlus_FontDispose($g_hFontZone)
    If $g_hFamilyUi <> 0 Then _GDIPlus_FontFamilyDispose($g_hFamilyUi)
    $g_hFontTitle = 0
    $g_hFontNormal = 0
    $g_hFontSmall = 0
    $g_hFontZone = 0
    $g_hFamilyUi = 0

    If $g_hBrushText <> 0 Then _GDIPlus_BrushDispose($g_hBrushText)
    If $g_hBrushMuted <> 0 Then _GDIPlus_BrushDispose($g_hBrushMuted)
    If $g_hBrushTextDisabled <> 0 Then _GDIPlus_BrushDispose($g_hBrushTextDisabled)
    If $g_hBrushAccent <> 0 Then _GDIPlus_BrushDispose($g_hBrushAccent)
    If $g_hBrushOk <> 0 Then _GDIPlus_BrushDispose($g_hBrushOk)
    If $g_hBrushError <> 0 Then _GDIPlus_BrushDispose($g_hBrushError)
    If $g_hBrushPanel <> 0 Then _GDIPlus_BrushDispose($g_hBrushPanel)
    If $g_hBrushTopBar <> 0 Then _GDIPlus_BrushDispose($g_hBrushTopBar)
    If $g_hBrushButton <> 0 Then _GDIPlus_BrushDispose($g_hBrushButton)
    If $g_hBrushButtonHover <> 0 Then _GDIPlus_BrushDispose($g_hBrushButtonHover)
    If $g_hBrushButtonDisabled <> 0 Then _GDIPlus_BrushDispose($g_hBrushButtonDisabled)
    If $g_hBrushAnalyze <> 0 Then _GDIPlus_BrushDispose($g_hBrushAnalyze)
    If $g_hBrushAnalyzeHover <> 0 Then _GDIPlus_BrushDispose($g_hBrushAnalyzeHover)
    If $g_hBrushWaveBg <> 0 Then _GDIPlus_BrushDispose($g_hBrushWaveBg)
    $g_hBrushText = 0
    $g_hBrushMuted = 0
    $g_hBrushTextDisabled = 0
    $g_hBrushAccent = 0
    $g_hBrushOk = 0
    $g_hBrushError = 0
    $g_hBrushPanel = 0
    $g_hBrushTopBar = 0
    $g_hBrushButton = 0
    $g_hBrushButtonHover = 0
    $g_hBrushButtonDisabled = 0
    $g_hBrushAnalyze = 0
    $g_hBrushAnalyzeHover = 0
    $g_hBrushWaveBg = 0

    If $g_hPenBorder <> 0 Then _GDIPlus_PenDispose($g_hPenBorder)
    If $g_hPenWaveLine <> 0 Then _GDIPlus_PenDispose($g_hPenWaveLine)
    If $g_hPenWave <> 0 Then _GDIPlus_PenDispose($g_hPenWave)
    If $g_hPenRuler <> 0 Then _GDIPlus_PenDispose($g_hPenRuler)
    $g_hPenBorder = 0
    $g_hPenWaveLine = 0
    $g_hPenWave = 0
    $g_hPenRuler = 0

    If $g_hFmtLeft <> 0 Then _GDIPlus_StringFormatDispose($g_hFmtLeft)
    If $g_hFmtCenter <> 0 Then _GDIPlus_StringFormatDispose($g_hFmtCenter)
    If $g_hFmtRight <> 0 Then _GDIPlus_StringFormatDispose($g_hFmtRight)
    If $g_hFmtCenterWrap <> 0 Then _GDIPlus_StringFormatDispose($g_hFmtCenterWrap)
    $g_hFmtLeft = 0
    $g_hFmtCenter = 0
    $g_hFmtRight = 0
    $g_hFmtCenterWrap = 0
EndFunc
