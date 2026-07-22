#include-once

; ---------------------------------------------------------------------------
; Layout : rectangles des zones et des boutons, recalculés au resize.
; Rects = tableaux [x, y, w, h] en coordonnées client (1:1 avec le backbuffer).
; Les hauteurs des zones source et bibliothèque sont ajustables par l'utilisateur
; (poignées entre les blocs) et persistées dans le fichier INI.
; ---------------------------------------------------------------------------

Global Const $BTN_OPEN_SOURCE = 0
Global Const $BTN_OPEN_SAMPLES = 1
Global Const $BTN_ANALYZE = 2
Global Const $BTN_PLAY = 3
Global Const $BTN_STOP = 4
Global Const $BTN_COUNT = 5

Global Const $LAYOUT_MARGIN = 10
Global Const $LAYOUT_TOPBAR_H = 56
Global Const $LAYOUT_STATUS_H = 26
Global Const $LAYOUT_SOURCE_DEFAULT_H = 200
Global Const $LAYOUT_SAMPLES_DEFAULT_H = 190
Global Const $LAYOUT_SOURCE_MIN_H = 120
Global Const $LAYOUT_SAMPLES_MIN_H = 80
Global Const $LAYOUT_TIMELINE_MIN_H = 90
Global Const $LAYOUT_SPLIT_GRAB = 5   ; demi-épaisseur de la zone de saisie (px)

; Hauteurs ajustables (restaurées depuis l'INI)
Global $g_iLayoutSourceH = $LAYOUT_SOURCE_DEFAULT_H
Global $g_iLayoutSamplesH = $LAYOUT_SAMPLES_DEFAULT_H

; Poignées de redimensionnement
Global Const $SPLIT_NONE = -1
Global Const $SPLIT_SOURCE = 0    ; entre source et timeline
Global Const $SPLIT_SAMPLES = 1   ; entre timeline et bibliothèque

Global $g_aButtonLabels[5] = ["Ouvrir source", "Dossier samples", "Analyser la composition", _
        "Lecture", "Stop"]
Global $g_aButtonWidths[5] = [130, 150, 210, 90, 70]
Global $g_aRectButtons[5][4]

Global $g_aRectTopBar[4]
Global $g_aRectSource[4]
Global $g_aRectWave[4]      ; bande waveform (règle + pics) dans la zone source
Global $g_aRectTimeline[4]
Global $g_aRectTlBlocks[4]  ; zone des blocs (timeline moins colonne labels)
Global Const $TL_LABEL_W = 150
Global $g_aRectSamples[4]
Global $g_aRectSamplesList[4] ; grille des noms (zone cliquable)
Global $g_aRectStatus[4]

; Dernière taille client connue (pour re-clamper après un changement de hauteur)
Global $g_iLayoutW = 0
Global $g_iLayoutH = 0

; Borne les hauteurs ajustables pour que la timeline garde sa place minimale.
Func Layout_ClampHeights()
    If $g_iLayoutSourceH < $LAYOUT_SOURCE_MIN_H Then $g_iLayoutSourceH = $LAYOUT_SOURCE_MIN_H
    If $g_iLayoutSamplesH < $LAYOUT_SAMPLES_MIN_H Then $g_iLayoutSamplesH = $LAYOUT_SAMPLES_MIN_H
    If $g_iLayoutH <= 0 Then Return
    ; Espace disponible entre la barre du haut et la barre de statut.
    ; Quatre marges séparent les blocs empilés :
    ; topbar |m| source |m| timeline |m| bibliothèque |m| statut
    Local $iFree = $g_iLayoutH - $LAYOUT_TOPBAR_H - $LAYOUT_STATUS_H - 4 * $LAYOUT_MARGIN
    Local $iMax = $iFree - $LAYOUT_TIMELINE_MIN_H
    If $iMax < $LAYOUT_SOURCE_MIN_H + $LAYOUT_SAMPLES_MIN_H Then
        $g_iLayoutSourceH = $LAYOUT_SOURCE_MIN_H
        $g_iLayoutSamplesH = $LAYOUT_SAMPLES_MIN_H
        Return
    EndIf
    ; Réduire d'abord la bibliothèque, puis la source
    If $g_iLayoutSourceH + $g_iLayoutSamplesH > $iMax Then
        $g_iLayoutSamplesH = $iMax - $g_iLayoutSourceH
        If $g_iLayoutSamplesH < $LAYOUT_SAMPLES_MIN_H Then
            $g_iLayoutSamplesH = $LAYOUT_SAMPLES_MIN_H
            $g_iLayoutSourceH = $iMax - $LAYOUT_SAMPLES_MIN_H
            If $g_iLayoutSourceH < $LAYOUT_SOURCE_MIN_H Then $g_iLayoutSourceH = $LAYOUT_SOURCE_MIN_H
        EndIf
    EndIf
EndFunc

Func Layout_Recompute($iW, $iH)
    $g_iLayoutW = $iW
    $g_iLayoutH = $iH
    Layout_ClampHeights()
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
        $iX -= ($i = $BTN_PLAY) ? 24 : 10 ; séparer le groupe transport
    Next

    ; Zones empilées : source / timeline (flexible) / bibliothèque / statut
    Local $iStatusY = $iH - $LAYOUT_STATUS_H
    _Layout_SetRect($g_aRectStatus, 0, $iStatusY, $iW, $LAYOUT_STATUS_H)

    Local $iSamplesY = $iStatusY - $m - $g_iLayoutSamplesH
    _Layout_SetRect($g_aRectSamples, $m, $iSamplesY, $iW - 2 * $m, $g_iLayoutSamplesH)
    _Layout_SetRect($g_aRectSamplesList, $m + 14, $iSamplesY + 48, _
            $iW - 2 * $m - 28, $g_iLayoutSamplesH - 48 - 10)

    Local $iSourceY = $LAYOUT_TOPBAR_H + $m
    _Layout_SetRect($g_aRectSource, $m, $iSourceY, $iW - 2 * $m, $g_iLayoutSourceH)
    _Layout_SetRect($g_aRectWave, $m + 14, $iSourceY + 68, $iW - 2 * $m - 28, $g_iLayoutSourceH - 68 - 12)

    Local $iTimelineY = $iSourceY + $g_iLayoutSourceH + $m
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

; Géométrie de la grille de la bibliothèque (partagée par le dessin et le
; hit-test : les deux doivent voir exactement les mêmes cases).
Func Layout_SampleGrid(ByRef $iCols, ByRef $iRows, ByRef $iColW, ByRef $iRowH)
    $iColW = 240
    $iRowH = 20
    $iCols = Int($g_aRectSamplesList[2] / $iColW)
    If $iCols < 1 Then $iCols = 1
    $iRows = Int($g_aRectSamplesList[3] / $iRowH)
    If $iRows < 1 Then $iRows = 1
EndFunc

; Index du sample sous (x, y) dans la grille, ou -1. $iShown = nombre de
; cases réellement dessinées (les suivantes sont résumées par « + N autres »).
Func Layout_HitSample($iX, $iY, $iShown)
    If Not Layout_PointInRect($iX, $iY, $g_aRectSamplesList) Then Return -1
    Local $iCols, $iRows, $iColW, $iRowH
    Layout_SampleGrid($iCols, $iRows, $iColW, $iRowH)
    Local $iCol = Int(($iX - $g_aRectSamplesList[0]) / $iColW)
    Local $iRow = Int(($iY - $g_aRectSamplesList[1]) / $iRowH)
    If $iCol < 0 Or $iCol >= $iCols Or $iRow < 0 Or $iRow >= $iRows Then Return -1
    Local $iIndex = $iCol * $iRows + $iRow
    If $iIndex >= $iShown Then Return -1
    Return $iIndex
EndFunc

; Poignée de redimensionnement sous (x, y) : bande centrée sur l'espace
; séparant deux zones. $SPLIT_NONE si aucune.
Func Layout_HitSplitter($iX, $iY)
    If $iX < $LAYOUT_MARGIN Or $iX > $g_iLayoutW - $LAYOUT_MARGIN Then Return $SPLIT_NONE
    Local $iSrcEdge = $g_aRectSource[1] + $g_aRectSource[3] + Int($LAYOUT_MARGIN / 2)
    If Abs($iY - $iSrcEdge) <= $LAYOUT_SPLIT_GRAB Then Return $SPLIT_SOURCE
    Local $iSmpEdge = $g_aRectSamples[1] - Int($LAYOUT_MARGIN / 2)
    If Abs($iY - $iSmpEdge) <= $LAYOUT_SPLIT_GRAB Then Return $SPLIT_SAMPLES
    Return $SPLIT_NONE
EndFunc

; Applique un déplacement de poignée (y souris) et recalcule le layout.
Func Layout_DragSplitter($iSplit, $iMouseY)
    Switch $iSplit
        Case $SPLIT_SOURCE
            $g_iLayoutSourceH = $iMouseY - $g_aRectSource[1] - Int($LAYOUT_MARGIN / 2)
        Case $SPLIT_SAMPLES
            $g_iLayoutSamplesH = ($g_iLayoutH - $LAYOUT_STATUS_H - $LAYOUT_MARGIN) - $iMouseY _
                    + Int($LAYOUT_MARGIN / 2)
        Case Else
            Return
    EndSwitch
    Layout_Recompute($g_iLayoutW, $g_iLayoutH)
EndFunc
