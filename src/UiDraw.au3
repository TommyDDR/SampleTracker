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

; Timeline (phase 6)
Global $g_aBrushPalette[12]
Global $g_hBrushUnknownFill = 0
Global $g_hBrushTooltipBg = 0
Global $g_hPenBlockHover = 0
Global $g_hPenUnknown = 0
Global $g_hPenAccent = 0
Global $g_hPenPlayhead = 0
Global $g_hBrushPlayhead = 0
Global $g_hBrushSplitter = 0
Global $g_hBrushPlayedBg = 0    ; fond du dernier élément joué
Global $g_hBrushScrollThumb = 0

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

    ; Palette de blocs (couleur stable par nom de sample)
    Local $aColors[12] = [0xFF4A78B0, 0xFF4AA07A, 0xFFAA7A3E, 0xFF9A5FA8, _
            0xFF4AA0A8, 0xFFB0684A, 0xFF6E8F3C, 0xFF5F74B8, _
            0xFFB08F3E, 0xFF3E8FB0, 0xFF8F5F8F, 0xFF5FA85F]
    Local $iC
    For $iC = 0 To 11
        $g_aBrushPalette[$iC] = _GDIPlus_BrushCreateSolid($aColors[$iC])
    Next
    $g_hBrushUnknownFill = _GDIPlus_BrushCreateSolid(0xFF4A2828)
    $g_hBrushTooltipBg = _GDIPlus_BrushCreateSolid(0xF5242430)
    $g_hPenBlockHover = _GDIPlus_PenCreate(0xFFE8E8F0, 2)
    $g_hPenUnknown = _GDIPlus_PenCreate($UI_COLOR_ERROR, 1)
    $g_hPenAccent = _GDIPlus_PenCreate($UI_COLOR_ACCENT, 1)
    $g_hPenPlayhead = _GDIPlus_PenCreate(0xFFF0C040, 1)
    $g_hBrushPlayhead = _GDIPlus_BrushCreateSolid(0xFFF0C040)
    $g_hBrushSplitter = _GDIPlus_BrushCreateSolid($UI_COLOR_ACCENT)
    $g_hBrushPlayedBg = _GDIPlus_BrushCreateSolid(0xFF1E3D2A)
    $g_hBrushScrollThumb = _GDIPlus_BrushCreateSolid(0xFF4A4A58)

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
            & (App_IsAnalyzeReady() ? 1 : 0) & "|" & $sStatus & "|" _
            & $g_bAnalyzing & "|" & $g_iEngineProgress & "|" & $g_iResultsVersion & "|" _
            & $g_sEngineLastLine & "|" & $g_iHoverBlock & "|" _
            & ($g_iHoverBlock >= 0 ? $g_iHoverX & ":" & $g_iHoverY : "") & "|" _
            & $g_iHoverSplitter & "|" & $g_iDragSplitter & "|" _
            & $g_iLayoutSourceH & "|" & $g_iLayoutSamplesH & "|" _
            & $g_iHoverSample & "|" & $g_iSamplesScroll & "|" & $g_bSamplesMore & "|" _
            & $g_iHoverLane & "|" & $g_sLastPlayed & "|" _
            & $g_bSrcOpen & "|" & $g_bSrcPlaying & "|" _
            & Round(Player_Position(), 2) ; tête de lecture : 50 redraws/s max
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
    Ui_DrawSplitters()
    Ui_DrawStatusBar()
    Ui_DrawTooltips() ; en dernier : toujours au-dessus du reste
EndFunc

; Poignées de redimensionnement : trait discret quand survolé ou tiré.
Func Ui_DrawSplitters()
    Local $iActive = ($g_iDragSplitter <> $SPLIT_NONE) ? $g_iDragSplitter : $g_iHoverSplitter
    If $iActive = $SPLIT_NONE Then Return
    Local $iY
    If $iActive = $SPLIT_SOURCE Then
        $iY = $g_aRectSource[1] + $g_aRectSource[3] + Int($LAYOUT_MARGIN / 2)
    Else
        $iY = $g_aRectSamples[1] - Int($LAYOUT_MARGIN / 2)
    EndIf
    _GDIPlus_GraphicsFillRect($g_hGfx, $LAYOUT_MARGIN, $iY - 1, _
            $g_iRenderW - 2 * $LAYOUT_MARGIN, 2, $g_hBrushSplitter)
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
    Local $bEnabled = True
    Switch $iIndex
        Case $BTN_ANALYZE
            $bEnabled = App_IsAnalyzeReady() And Not $g_bAnalyzing
        Case $BTN_PLAY, $BTN_STOP
            $bEnabled = $g_bSrcOpen
    EndSwitch
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
    ; Le bouton Lecture bascule en Pause pendant la lecture
    Local $sLabel = $g_aButtonLabels[$iIndex]
    If $iIndex = $BTN_PLAY And $g_bSrcPlaying Then $sLabel = "Pause"
    Ui_DrawText($sLabel, $g_hFontSmall, $iX, $iY, $iW, $iH, $hText, $g_hFmtCenter)
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

    ; Colonne de libellés (même largeur que celle de la timeline) : nom du
    ; fichier et informations, la bande d'onde commence après le séparateur.
    Local $iColX = $aR[0] + 14
    Local $iColW = $TL_LABEL_W - 24
    Ui_DrawText(Ui_EllipsizeEnd(Action_FileName($g_sSourcePath), 20), $g_hFontNormal, _
            $iColX, $aR[1] + 26, $iColW, 20, $g_hBrushAccent, $g_hFmtLeft)
    Local $sInfo = ""
    Local $hInfoBrush = $g_hBrushMuted
    If $g_bExtracting Then
        Local $iDots = Mod(Int(TimerDiff($g_hExtractTimer) / 400), 4)
        $sInfo = "Extraction" & StringLeft("...", $iDots)
        $hInfoBrush = $g_hBrushAccent
    ElseIf $g_sSourceWav <> "" Then
        $sInfo = StringFormat("%.2f s — %.1f kHz", $g_fSourceDuration, $g_iSourceRate / 1000)
    EndIf
    Ui_DrawText($sInfo, $g_hFontSmall, $iColX, $aR[1] + 46, $iColW, 16, $hInfoBrush, $g_hFmtLeft)
    Ui_DrawText("mono 16 bits", $g_hFontSmall, $iColX, $aR[1] + 62, $iColW, 16, _
            $g_hBrushMuted, $g_hFmtLeft)
    If $g_fWaveYZoom > 1 Then
        Ui_DrawText(StringFormat("amplitude ×%.1f", $g_fWaveYZoom), $g_hFontSmall, _
                $iColX, $aR[1] + 82, $iColW, 16, $g_hBrushMuted, $g_hFmtLeft)
    EndIf

    ; Séparateur vertical entre la colonne de libellés et la bande d'onde
    Ui_DrawTrackSeparator($aR)

    ; Bande waveform : règle + pics
    Ui_DrawWaveform()
EndFunc

; Trait vertical séparant la colonne de libellés de la zone de tracé.
Func Ui_DrawTrackSeparator($aZoneRect)
    Local $iX = $aZoneRect[0] + $TL_LABEL_W - 6
    _GDIPlus_GraphicsDrawLine($g_hGfx, $iX, $aZoneRect[1] + 6, _
            $iX, $aZoneRect[1] + $aZoneRect[3] - 6, $g_hPenBorder)
EndFunc

; Limite tout tracé au rectangle donné : rien ne peut déborder de la zone
; (remplace le découpage en fenêtres enfants, et garde un seul blit par frame).
Func Ui_SetClip($aRect)
    _GDIPlus_GraphicsSetClipRect($g_hGfx, $aRect[0], $aRect[1], $aRect[2], $aRect[3])
EndFunc

Func Ui_ResetClip()
    _GDIPlus_GraphicsResetClip($g_hGfx)
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
    ; Tout le tracé qui suit est borné à la bande : aucun débordement possible
    Ui_SetClip($aR)
    _GDIPlus_GraphicsDrawLine($g_hGfx, $aR[0], $fMid, $aR[0] + $aR[2], $fMid, $g_hPenWaveLine)

    Local $fSecPerPx = $g_fViewDur / $aR[2]
    Local $fScale = $fHalf * $g_fWaveYZoom / 32768
    Local $iClipTop = $iWaveY + 1
    Local $iClipBottom = $iWaveY + $iWaveH - 2
    Local $fBucketDur = Waveform_GetBucketDur()

    Local $fSamplesPerPx = $fSecPerPx * $g_iWaveRate

    If $g_tWaveShorts <> 0 And $fSamplesPerPx < 64 Then
        ; Zoom profond : polyligne sur les échantillons PCM réels (la vraie
        ; forme d'onde), 2 points par pixel max, antialiasing temporaire.
        Local $iStep = Int($fSamplesPerPx / 2)
        If $iStep < 1 Then $iStep = 1
        Local $iS0 = Int($g_fViewStart * $g_iWaveRate)
        Local $iS1 = Int(($g_fViewStart + $g_fViewDur) * $g_iWaveRate) + 1
        If $iS0 < 0 Then $iS0 = 0
        If $iS1 > $g_iWaveSampleCount - 1 Then $iS1 = $g_iWaveSampleCount - 1
        _GDIPlus_GraphicsSetSmoothingMode($g_hGfx, 2)
        Local $iS, $fSX, $iSY, $v
        Local $fPrevSX = 0, $iPrevSY = 0, $bPrevS = False
        For $iS = $iS0 To $iS1 Step $iStep
            $v = DllStructGetData($g_tWaveShorts, 1, $iS + 1)
            $fSX = $aR[0] + ($iS / $g_iWaveRate - $g_fViewStart) / $fSecPerPx
            $iSY = Int($fMid - $v * $fScale)
            If $iSY < $iClipTop Then $iSY = $iClipTop
            If $iSY > $iClipBottom Then $iSY = $iClipBottom
            If $bPrevS Then _GDIPlus_GraphicsDrawLine($g_hGfx, $fPrevSX, $iPrevSY, $fSX, $iSY, $g_hPenWave)
            $fPrevSX = $fSX
            $iPrevSY = $iSY
            $bPrevS = True
        Next
        _GDIPlus_GraphicsSetSmoothingMode($g_hGfx, 0) ; restaurer (doc rendu §3)
    ElseIf $fBucketDur > 0 And $fSecPerPx < $fBucketDur Then
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
    ; Tête de lecture par-dessus la waveform
    Ui_DrawPlayhead($aR, $g_fViewStart, $g_fViewDur)
    Ui_ResetClip()
EndFunc

; Trait vertical de la tête de lecture + petit repère en haut.
Func Ui_DrawPlayhead($aRect, $fViewStart, $fViewDur)
    If Not $g_bSrcOpen Or $fViewDur <= 0 Then Return
    Local $fPos = Player_Position()
    If $fPos < $fViewStart Or $fPos > $fViewStart + $fViewDur Then Return
    Local $iX = $aRect[0] + Int(($fPos - $fViewStart) * $aRect[2] / $fViewDur)
    _GDIPlus_GraphicsDrawLine($g_hGfx, $iX, $aRect[1], $iX, $aRect[1] + $aRect[3], $g_hPenPlayhead)
    _GDIPlus_GraphicsFillRect($g_hGfx, $iX - 3, $aRect[1], 7, 5, $g_hBrushPlayhead)
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
    ; Démarrer une graduation avant le bord gauche : son libellé reste lisible,
    ; collé au bord, au lieu de disparaître dès que le trait sort de la vue.
    Local $fT = Ceiling($g_fViewStart / $fStep) * $fStep - $fStep
    Local $iLabelW = $bFine ? 52 : 34
    Local $iNextFreeX = $iX ; borne anti-chevauchement des libellés
    Local $iPx, $iLabelX
    While $fT <= $g_fViewStart + $g_fViewDur
        If $fT >= -0.0001 Then
            $iPx = $iX + Int(($fT - $g_fViewStart) * $fPxPerSec)
            If $iPx >= $iX And $iPx < $iX + $iW Then _
                    _GDIPlus_GraphicsDrawLine($g_hGfx, $iPx, $iY + $iH - 5, $iPx, $iY + $iH, $g_hPenRuler)
            ; Libellé maintenu dans la bande : celui de la graduation sortie à
            ; gauche reste collé au bord, sans jamais recouvrir le suivant.
            $iLabelX = $iPx + 3
            If $iLabelX < $iX + 2 Then $iLabelX = $iX + 2
            If $iLabelX >= $iNextFreeX And $iLabelX < $iX + $iW Then
                Ui_DrawText(Ui_FormatTime($fT, $bFine), $g_hFontSmall, $iLabelX, $iY, 80, $iH - 4, _
                        $g_hBrushMuted, $g_hFmtLeft)
                $iNextFreeX = $iLabelX + $iLabelW
            EndIf
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

    If $g_bAnalyzing Then
        ; Barre de progression du moteur
        Local $iBarW = $aR[2] - 200
        If $iBarW < 100 Then $iBarW = 100
        Local $iBarX = $aR[0] + Int(($aR[2] - $iBarW) / 2)
        Local $iBarY = $aR[1] + Int($aR[3] / 2) - 10
        _GDIPlus_GraphicsDrawRect($g_hGfx, $iBarX, $iBarY, $iBarW, 20, $g_hPenBorder)
        _GDIPlus_GraphicsFillRect($g_hGfx, $iBarX + 2, $iBarY + 2, _
                Int(($iBarW - 4) * $g_iEngineProgress / 100), 16, $g_hBrushAccent)
        Ui_DrawText("Analyse en cours — " & $g_iEngineProgress & " %", $g_hFontNormal, _
                $aR[0], $iBarY - 30, $aR[2], 24, $g_hBrushText, $g_hFmtCenter)
        Ui_DrawText(Ui_EllipsizeEnd($g_sEngineLastLine, 100), $g_hFontSmall, _
                $aR[0], $iBarY + 26, $aR[2], 20, $g_hBrushMuted, $g_hFmtCenter)
        Return
    EndIf

    If $g_iTlBlocks > 0 Then
        Ui_DrawTimelineTracks()
        Return
    EndIf

    Ui_DrawText("Les blocs de détection s'afficheront ici après analyse", _
            $g_hFontNormal, $aR[0], $aR[1], $aR[2], $aR[3], $g_hBrushMuted, $g_hFmtCenterWrap)
EndFunc

; Vue temporelle pour la timeline (celle de la waveform, sinon source entière).
Func Ui_GetTimelineView(ByRef $fStart, ByRef $fDur)
    If $g_fViewDur > 0 Then
        $fStart = $g_fViewStart
        $fDur = $g_fViewDur
    Else
        $fStart = 0
        $fDur = $g_fSourceDuration
        If $fDur <= 0 Then $fDur = 1
    EndIf
EndFunc

; Pistes MAO : labels à gauche, blocs positionnés sur la vue temporelle.
Func Ui_DrawTimelineTracks()
    Local $aB = $g_aRectTlBlocks
    Local $fViewStart, $fViewDur
    Ui_GetTimelineView($fViewStart, $fViewDur)
    Local $iRowH, $iVisible
    Timeline_LayoutRows($aB, $iRowH, $iVisible)
    Local $fPxPerSec = $aB[2] / $fViewDur

    ; Séparateur vertical entre la liste des pistes et la zone des blocs
    Ui_DrawTrackSeparator($g_aRectTimeline)

    ; Lignes de pistes + labels
    Local $iLane, $iY, $bPlayed
    For $iLane = 0 To $iVisible - 1
        $iY = $aB[1] + $iLane * $iRowH
        If $iY + $iRowH > $aB[1] + $aB[3] Then ExitLoop
        ; Piste du dernier sample joué : fond vert sur toute la ligne
        $bPlayed = ($g_aTlLaneKind[$iLane] = 0 And $g_sLastPlayed <> "" _
                And $g_aTlLaneName[$iLane] = $g_sLastPlayed)
        If $bPlayed Then _GDIPlus_GraphicsFillRect($g_hGfx, $g_aRectTimeline[0] + 4, $iY, _
                $g_aRectTimeline[2] - 8, $iRowH, $g_hBrushPlayedBg)
        _GDIPlus_GraphicsDrawLine($g_hGfx, $aB[0] - $TL_LABEL_W + 8, $iY + $iRowH, _
                $aB[0] + $aB[2], $iY + $iRowH, $g_hPenBorder)
        ; pastille couleur + nom de piste
        If $g_aTlLaneKind[$iLane] = 1 Then
            _GDIPlus_GraphicsFillRect($g_hGfx, $aB[0] - $TL_LABEL_W + 10, $iY + Int($iRowH / 2) - 4, 8, 8, $g_hBrushError)
            Ui_DrawText("INCONNU", $g_hFontSmall, $aB[0] - $TL_LABEL_W + 24, $iY, _
                    $TL_LABEL_W - 30, $iRowH, $g_hBrushError, $g_hFmtLeft)
        Else
            _GDIPlus_GraphicsFillRect($g_hGfx, $aB[0] - $TL_LABEL_W + 10, $iY + Int($iRowH / 2) - 4, 8, 8, _
                    $g_aBrushPalette[$g_aTlLaneColor[$iLane]])
            Ui_DrawText(Ui_EllipsizeEnd($g_aTlLaneName[$iLane], 20), $g_hFontSmall, _
                    $aB[0] - $TL_LABEL_W + 24, $iY, $TL_LABEL_W - 30, $iRowH, _
                    $bPlayed ? $g_hBrushOk : (($iLane = $g_iHoverLane) ? $g_hBrushAccent : $g_hBrushText), _
                    $g_hFmtLeft)
        EndIf
    Next
    If $iVisible < $g_iTlLanes Then
        Ui_DrawText("+ " & ($g_iTlLanes - $iVisible) & " pistes", $g_hFontSmall, _
                $aB[0] - $TL_LABEL_W + 10, $aB[1] + $aB[3] - 16, $TL_LABEL_W, 16, $g_hBrushMuted, $g_hFmtLeft)
    EndIf

    ; Blocs — bornés à la zone (aucun débordement sur la colonne de libellés
    ; ni hors du panneau)
    Ui_SetClip($aB)
    Local $i, $iX1, $iX2, $iBY, $iBH, $iHatch
    For $i = 0 To $g_iTlBlocks - 1
        $iLane = $g_aTlBlocks[$i][0]
        If $iLane >= $iVisible Then ContinueLoop
        $iX1 = $aB[0] + Int(($g_aTlBlocks[$i][1] - $fViewStart) * $fPxPerSec)
        $iX2 = $aB[0] + Int(($g_aTlBlocks[$i][1] + $g_aTlBlocks[$i][2] - $fViewStart) * $fPxPerSec)
        If $iX2 < $aB[0] Or $iX1 > $aB[0] + $aB[2] Then ContinueLoop
        If $iX1 < $aB[0] Then $iX1 = $aB[0]
        If $iX2 > $aB[0] + $aB[2] Then $iX2 = $aB[0] + $aB[2]
        If $iX2 - $iX1 < 2 Then $iX2 = $iX1 + 2
        $iBY = $aB[1] + $iLane * $iRowH + 3
        $iBH = $iRowH - 6
        If $g_aTlBlocks[$i][3] = 1 Then
            ; INCONNU : fond sombre + hachures diagonales + bord rouge
            _GDIPlus_GraphicsFillRect($g_hGfx, $iX1, $iBY, $iX2 - $iX1, $iBH, $g_hBrushUnknownFill)
            For $iHatch = $iX1 - $iBH To $iX2 Step 8
                _GDIPlus_GraphicsDrawLine($g_hGfx, _
                        ($iHatch < $iX1) ? $iX1 : $iHatch, _
                        ($iHatch < $iX1) ? $iBY + ($iX1 - $iHatch) : $iBY, _
                        (($iHatch + $iBH) > $iX2) ? $iX2 : $iHatch + $iBH, _
                        (($iHatch + $iBH) > $iX2) ? $iBY + ($iX2 - $iHatch) : $iBY + $iBH, $g_hPenUnknown)
            Next
            _GDIPlus_GraphicsDrawRect($g_hGfx, $iX1, $iBY, $iX2 - $iX1 - 1, $iBH - 1, $g_hPenUnknown)
        Else
            _GDIPlus_GraphicsFillRect($g_hGfx, $iX1, $iBY, $iX2 - $iX1, $iBH, _
                    $g_aBrushPalette[$g_aTlLaneColor[$iLane]])
            _GDIPlus_GraphicsDrawRect($g_hGfx, $iX1, $iBY, $iX2 - $iX1 - 1, $iBH - 1, $g_hPenBorder)
        EndIf
        If $i = $g_iHoverBlock Then _
                _GDIPlus_GraphicsDrawRect($g_hGfx, $iX1, $iBY, $iX2 - $iX1 - 1, $iBH - 1, $g_hPenBlockHover)
        If $iX2 - $iX1 > 44 Then
            Ui_DrawText(" " & Ui_EllipsizeEnd($g_aTlBlocks[$i][6], Int(($iX2 - $iX1) / 7)), _
                    $g_hFontSmall, $iX1, $iBY, $iX2 - $iX1, $iBH, $g_hBrushText, $g_hFmtLeft)
        EndIf
    Next

    Ui_DrawPlayhead($aB, $fViewStart, $fViewDur)
    Ui_ResetClip()

EndFunc

; Infobulles : dessinées tout à la fin de la frame (Ui_Redraw), donc
; par-dessus tous les panneaux, y compris ceux tracés après la timeline.
Func Ui_DrawTooltips()
    If $g_iHoverBlock >= 0 And $g_iHoverBlock < $g_iTlBlocks Then
        Ui_DrawBlockTooltip()
    ElseIf $g_iHoverLane >= 0 And $g_iHoverLane < $g_iTlLanes Then
        ; Libellé de piste tronqué : nom complet en infobulle
        Ui_DrawNameTooltip($g_aTlLaneName[$g_iHoverLane], $g_aTlLaneKind[$g_iHoverLane] = 1)
    EndIf
EndFunc

; Infobulle d'une seule ligne, dimensionnée sur le texte.
Func Ui_DrawNameTooltip($sText, $bUnknown)
    Local $iW = Ui_MeasureTextW($sText, $g_hFontSmall) + 20
    If $iW < 80 Then $iW = 80
    Local $iH = 24
    Local $iX = $g_iHoverX + 16
    Local $iY = $g_iHoverY + 16
    If $iX + $iW > $g_iRenderW - 4 Then $iX = $g_iRenderW - 4 - $iW
    If $iX < 4 Then $iX = 4
    If $iY + $iH > $g_iRenderH - 4 Then $iY = $g_iHoverY - $iH - 8
    _GDIPlus_GraphicsFillRect($g_hGfx, $iX, $iY, $iW, $iH, $g_hBrushTooltipBg)
    _GDIPlus_GraphicsDrawRect($g_hGfx, $iX, $iY, $iW - 1, $iH - 1, $g_hPenAccent)
    Ui_DrawText($sText, $g_hFontSmall, $iX + 10, $iY, $iW - 20, $iH, _
            $bUnknown ? $g_hBrushError : $g_hBrushText, $g_hFmtLeft)
EndFunc

; Largeur d'un texte en pixels (mesure GDI+, uniquement hors chemin chaud).
Func Ui_MeasureTextW($sText, $hFont)
    Local $tLayout = _GDIPlus_RectFCreate(0, 0, 2000, 40)
    Local $aInfo = _GDIPlus_GraphicsMeasureString($g_hGfx, $sText, $hFont, $tLayout, $g_hFmtLeft)
    If @error Then Return 8 * StringLen($sText)
    Return Int(DllStructGetData($aInfo[0], "Width")) + 2
EndFunc

Func Ui_DrawBlockTooltip()
    Local $i = $g_iHoverBlock
    ; Largeur ajustée au nom : jamais tronqué, même très long
    Local $iW = Ui_MeasureTextW($g_aTlBlocks[$i][6], $g_hFontNormal) + 24
    If $iW < 240 Then $iW = 240
    If $iW > $g_iRenderW - 40 Then $iW = $g_iRenderW - 40
    Local $iH = 88
    Local $iX = $g_iHoverX + 16
    Local $iY = $g_iHoverY + 16
    If $iX + $iW > $g_iRenderW - 4 Then $iX = $g_iHoverX - $iW - 8
    If $iY + $iH > $g_iRenderH - 4 Then $iY = $g_iHoverY - $iH - 8
    _GDIPlus_GraphicsFillRect($g_hGfx, $iX, $iY, $iW, $iH, $g_hBrushTooltipBg)
    _GDIPlus_GraphicsDrawRect($g_hGfx, $iX, $iY, $iW - 1, $iH - 1, $g_hPenAccent)
    Local $bUnknown = ($g_aTlBlocks[$i][3] = 1)
    Ui_DrawText($g_aTlBlocks[$i][6], $g_hFontNormal, $iX + 10, $iY + 4, $iW - 20, 22, _
            $bUnknown ? $g_hBrushError : $g_hBrushAccent, $g_hFmtLeft)
    Ui_DrawText(StringFormat("%s  →  %s   (%.3f s)", _
            Ui_FormatTime($g_aTlBlocks[$i][1], True), _
            Ui_FormatTime($g_aTlBlocks[$i][1] + $g_aTlBlocks[$i][2], True), _
            $g_aTlBlocks[$i][2]), _
            $g_hFontSmall, $iX + 10, $iY + 28, $iW - 20, 18, $g_hBrushText, $g_hFmtLeft)
    If $bUnknown Then
        Ui_DrawText(StringFormat("niveau : %.1f dB", $g_aTlBlocks[$i][4]), _
                $g_hFontSmall, $iX + 10, $iY + 48, $iW - 20, 18, $g_hBrushText, $g_hFmtLeft)
        Ui_DrawText("absent de la bibliothèque", $g_hFontSmall, _
                $iX + 10, $iY + 66, $iW - 20, 18, $g_hBrushMuted, $g_hFmtLeft)
    Else
        Ui_DrawText(StringFormat("gain : %.1f dB", $g_aTlBlocks[$i][4]), _
                $g_hFontSmall, $iX + 10, $iY + 48, $iW - 20, 18, $g_hBrushText, $g_hFmtLeft)
        Ui_DrawText(StringFormat("confiance : %.2f", $g_aTlBlocks[$i][5]), _
                $g_hFontSmall, $iX + 10, $iY + 66, $iW - 20, 18, $g_hBrushText, $g_hFmtLeft)
    EndIf
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

    ; Grille de noms (lignes puis colonnes) — géométrie partagée avec le
    ; hit-test, défilement vertical borné à la liste.
    Local $aL = $g_aRectSamplesList
    Local $iCols, $iRows, $iColW, $iRowH
    Layout_SampleGrid($iCols, $iRows, $iColW, $iRowH)
    Layout_ClampSamplesScroll($iCount)
    Local $iFirst = $g_iSamplesScroll * $iCols
    Local $iLast = $iFirst + $iCols * $iRows - 1
    If $iLast > $iCount - 1 Then $iLast = $iCount - 1

    Ui_SetClip($aL)
    Local $i, $iCol, $iRow, $iCellX, $iCellY, $hBrush, $sName
    For $i = $iFirst To $iLast
        $iCol = Mod($i - $iFirst, $iCols)
        $iRow = Int(($i - $iFirst) / $iCols)
        $iCellX = $aL[0] + $iCol * $iColW
        $iCellY = $aL[1] + $iRow * $iRowH
        $sName = $g_aSampleFiles[$i]
        $hBrush = $g_hBrushText
        If $i = $g_iHoverSample Then
            ; survol : fond discret, le clic déclenche la prévisualisation
            _GDIPlus_GraphicsFillRect($g_hGfx, $iCellX - 2, $iCellY, $iColW - 6, $iRowH, _
                    $g_hBrushButtonHover)
            $hBrush = $g_hBrushAccent
        EndIf
        ; Dernier sample joué : reste en vert jusqu'à la lecture du suivant
        If $sName = $g_sLastPlayed Then
            _GDIPlus_GraphicsFillRect($g_hGfx, $iCellX - 2, $iCellY, $iColW - 6, $iRowH, _
                    $g_hBrushPlayedBg)
            $hBrush = $g_hBrushOk
        EndIf
        Ui_DrawText("• " & Ui_EllipsizeEnd($sName, 32), $g_hFontSmall, _
                $iCellX, $iCellY, $iColW - 10, $iRowH, $hBrush, $g_hFmtLeft)
    Next
    Ui_ResetClip()

    Ui_DrawSamplesScrollbar($aL, $iCount, $iCols, $iRows)
EndFunc

; Barre de défilement de la bibliothèque + rappel du nombre restant.
Func Ui_DrawSamplesScrollbar($aL, $iCount, $iCols, $iRows)
    Local $iMaxScroll = Layout_SampleMaxScroll($iCount)
    If $iMaxScroll <= 0 Then Return
    Local $iBarX = $aL[0] + $aL[2] - $LAYOUT_SCROLLBAR_W
    _GDIPlus_GraphicsFillRect($g_hGfx, $iBarX, $aL[1], $LAYOUT_SCROLLBAR_W, $aL[3], $g_hBrushWaveBg)
    Local $iTotalRows = $iMaxScroll + $iRows
    Local $iThumbH = Int($aL[3] * $iRows / $iTotalRows)
    If $iThumbH < 16 Then $iThumbH = 16
    Local $iThumbY = $aL[1] + Int(($aL[3] - $iThumbH) * $g_iSamplesScroll / $iMaxScroll)
    _GDIPlus_GraphicsFillRect($g_hGfx, $iBarX + 1, $iThumbY, $LAYOUT_SCROLLBAR_W - 2, $iThumbH, _
            $g_hBrushScrollThumb)
    ; Reste à afficher : ligne cliquable qui fait défiler d'une page
    Local $iRemaining = $iCount - ($g_iSamplesScroll + $iRows) * $iCols
    If $iRemaining > 0 Then
        Ui_DrawText("+ " & $iRemaining & " autres…", $g_hFontSmall, _
                $aL[0], $aL[1] - 20, $aL[2] - $LAYOUT_SCROLLBAR_W - 4, 18, _
                $g_bSamplesMore ? $g_hBrushAccent : $g_hBrushMuted, $g_hFmtRight)
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

    Local $iC
    For $iC = 0 To 11
        If $g_aBrushPalette[$iC] <> 0 Then _GDIPlus_BrushDispose($g_aBrushPalette[$iC])
        $g_aBrushPalette[$iC] = 0
    Next
    If $g_hBrushUnknownFill <> 0 Then _GDIPlus_BrushDispose($g_hBrushUnknownFill)
    If $g_hBrushTooltipBg <> 0 Then _GDIPlus_BrushDispose($g_hBrushTooltipBg)
    If $g_hPenBlockHover <> 0 Then _GDIPlus_PenDispose($g_hPenBlockHover)
    If $g_hPenUnknown <> 0 Then _GDIPlus_PenDispose($g_hPenUnknown)
    If $g_hPenAccent <> 0 Then _GDIPlus_PenDispose($g_hPenAccent)
    If $g_hPenPlayhead <> 0 Then _GDIPlus_PenDispose($g_hPenPlayhead)
    If $g_hBrushPlayhead <> 0 Then _GDIPlus_BrushDispose($g_hBrushPlayhead)
    If $g_hBrushSplitter <> 0 Then _GDIPlus_BrushDispose($g_hBrushSplitter)
    If $g_hBrushPlayedBg <> 0 Then _GDIPlus_BrushDispose($g_hBrushPlayedBg)
    If $g_hBrushScrollThumb <> 0 Then _GDIPlus_BrushDispose($g_hBrushScrollThumb)
    $g_hBrushPlayedBg = 0
    $g_hBrushScrollThumb = 0
    $g_hBrushUnknownFill = 0
    $g_hBrushTooltipBg = 0
    $g_hPenBlockHover = 0
    $g_hPenUnknown = 0
    $g_hPenAccent = 0
    $g_hPenPlayhead = 0
    $g_hBrushPlayhead = 0
    $g_hBrushSplitter = 0

    If $g_hFmtLeft <> 0 Then _GDIPlus_StringFormatDispose($g_hFmtLeft)
    If $g_hFmtCenter <> 0 Then _GDIPlus_StringFormatDispose($g_hFmtCenter)
    If $g_hFmtRight <> 0 Then _GDIPlus_StringFormatDispose($g_hFmtRight)
    If $g_hFmtCenterWrap <> 0 Then _GDIPlus_StringFormatDispose($g_hFmtCenterWrap)
    $g_hFmtLeft = 0
    $g_hFmtCenter = 0
    $g_hFmtRight = 0
    $g_hFmtCenterWrap = 0
EndFunc
