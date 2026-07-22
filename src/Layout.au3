#include-once

; ---------------------------------------------------------------------------
; Layout : rectangles des zones et des boutons, recalculés au resize.
; Rects = tableaux [x, y, w, h] en coordonnées client (1:1 avec le backbuffer).
; ---------------------------------------------------------------------------

Global Const $BTN_OPEN_SOURCE = 0
Global Const $BTN_OPEN_SAMPLES = 1
Global Const $BTN_ANALYZE = 2
Global Const $BTN_COUNT = 3

Global Const $LAYOUT_MARGIN = 10
Global Const $LAYOUT_TOPBAR_H = 56
Global Const $LAYOUT_SOURCE_H = 200
Global Const $LAYOUT_SAMPLES_H = 190
Global Const $LAYOUT_STATUS_H = 26

Global $g_aButtonLabels[3] = ["Ouvrir source", "Dossier samples", "Analyser la composition"]
Global $g_aButtonWidths[3] = [130, 150, 210]
Global $g_aRectButtons[3][4]

Global $g_aRectTopBar[4]
Global $g_aRectSource[4]
Global $g_aRectWave[4]   ; bande waveform (règle + pics) dans la zone source
Global $g_aRectTimeline[4]
Global $g_aRectTlBlocks[4]  ; zone des blocs (timeline moins colonne labels)
Global Const $TL_LABEL_W = 150
Global $g_aRectSamples[4]
Global $g_aRectStatus[4]

Func Layout_Recompute($iW, $iH)
    Local $m = $LAYOUT_MARGIN

    _Layout_SetRect($g_aRectTopBar, 0, 0, $iW, $LAYOUT_TOPBAR_H)

    ; Boutons alignés à droite dans la barre du haut
    Local $iBtnH = 32
    Local $iBtnY = Int(($LAYOUT_TOPBAR_H - $iBtnH) / 2)
    Local $iX = $iW - $m
    Local $i
    For $i = $BTN_COUNT - 1 To 0 Step -1
        $iX -= $g_aButtonWidths[$i]
        $g_aRectButtons[$i][0] = $iX
        $g_aRectButtons[$i][1] = $iBtnY
        $g_aRectButtons[$i][2] = $g_aButtonWidths[$i]
        $g_aRectButtons[$i][3] = $iBtnH
        $iX -= 10
    Next

    ; Zones empilées : source / timeline (flexible) / samples / statut
    Local $iStatusY = $iH - $LAYOUT_STATUS_H
    _Layout_SetRect($g_aRectStatus, 0, $iStatusY, $iW, $LAYOUT_STATUS_H)

    Local $iSamplesY = $iStatusY - $m - $LAYOUT_SAMPLES_H
    _Layout_SetRect($g_aRectSamples, $m, $iSamplesY, $iW - 2 * $m, $LAYOUT_SAMPLES_H)

    Local $iSourceY = $LAYOUT_TOPBAR_H + $m
    _Layout_SetRect($g_aRectSource, $m, $iSourceY, $iW - 2 * $m, $LAYOUT_SOURCE_H)
    _Layout_SetRect($g_aRectWave, $m + 14, $iSourceY + 68, $iW - 2 * $m - 28, $LAYOUT_SOURCE_H - 68 - 12)

    Local $iTimelineY = $iSourceY + $LAYOUT_SOURCE_H + $m
    Local $iTimelineH = $iSamplesY - $m - $iTimelineY
    If $iTimelineH < 40 Then $iTimelineH = 40
    _Layout_SetRect($g_aRectTimeline, $m, $iTimelineY, $iW - 2 * $m, $iTimelineH)
    _Layout_SetRect($g_aRectTlBlocks, $m + $TL_LABEL_W, $iTimelineY + 24, _
            $iW - 2 * $m - $TL_LABEL_W - 12, $iTimelineH - 24 - 10)
EndFunc

Func _Layout_SetRect(ByRef $aRect, $iX, $iY, $iW, $iH)
    $aRect[0] = $iX
    $aRect[1] = $iY
    $aRect[2] = $iW
    $aRect[3] = $iH
EndFunc

Func Layout_PointInRect($iX, $iY, $aRect)
    Return $iX >= $aRect[0] And $iX < $aRect[0] + $aRect[2] _
            And $iY >= $aRect[1] And $iY < $aRect[1] + $aRect[3]
EndFunc

; Retourne l'index du bouton sous (x, y), ou -1.
Func Layout_HitButton($iX, $iY)
    Local $i
    For $i = 0 To $BTN_COUNT - 1
        If $iX >= $g_aRectButtons[$i][0] And $iX < $g_aRectButtons[$i][0] + $g_aRectButtons[$i][2] _
                And $iY >= $g_aRectButtons[$i][1] And $iY < $g_aRectButtons[$i][1] + $g_aRectButtons[$i][3] Then Return $i
    Next
    Return -1
EndFunc
