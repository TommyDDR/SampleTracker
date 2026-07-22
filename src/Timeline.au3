#include-once

; ---------------------------------------------------------------------------
; Timeline MAO : affectation des détections/inconnus à des pistes (lanes).
; Une piste par nom de sample, sous-piste supplémentaire si deux occurrences
; du même sample se chevauchent. Piste(s) INCONNU en fin.
; Aucune dépendance UI : module testable en CLI.
; ---------------------------------------------------------------------------

Global Const $TL_MAX_LANES = 64
Global Const $TL_PALETTE_COUNT = 12

; Pistes
Global $g_aTlLaneName[0]
Global $g_aTlLaneKind[0]    ; 0 = sample, 1 = inconnu
Global $g_aTlLaneColor[0]   ; index palette
Global $g_iTlLanes = 0

; Blocs : [0] lane, [1] start, [2] durée, [3] kind, [4] gain_db (ou rms_db),
;         [5] confidence, [6] nom
Global $g_aTlBlocks[0][7]
Global $g_iTlBlocks = 0

Func Timeline_Clear()
    ReDim $g_aTlLaneName[0]
    ReDim $g_aTlLaneKind[0]
    ReDim $g_aTlLaneColor[0]
    ReDim $g_aTlBlocks[0][7]
    $g_iTlLanes = 0
    $g_iTlBlocks = 0
EndFunc

; Couleur stable par nom (indépendante de l'ordre des pistes).
Func Timeline_ColorIndex($sName)
    Local $aChars = StringToASCIIArray($sName)
    Local $iSum = 0
    Local $i
    For $i = 0 To UBound($aChars) - 1
        $iSum += $aChars[$i]
    Next
    Return Mod($iSum, $TL_PALETTE_COUNT)
EndFunc

; Reconstruit pistes + blocs depuis $g_aDetections / $g_aUnknowns (Engine.au3).
Func Timeline_Rebuild()
    Timeline_Clear()
    Local $aName[$TL_MAX_LANES], $aEnd[$TL_MAX_LANES], $aKind[$TL_MAX_LANES]
    Local $iLanes = 0
    Local $iTotal = $g_iDetections + $g_iUnknowns
    If $iTotal = 0 Then Return
    ReDim $g_aTlBlocks[$iTotal][7]

    Local $i, $j, $iLane, $sName, $fStart, $fDur
    ; Détections (triées par start côté moteur : le glouton par piste est valide)
    For $i = 0 To $g_iDetections - 1
        $sName = $g_aDetections[$i][0]
        $fStart = $g_aDetections[$i][1]
        $fDur = $g_aDetections[$i][2]
        $iLane = -1
        For $j = 0 To $iLanes - 1
            If $aKind[$j] = 0 And $aName[$j] = $sName And $aEnd[$j] <= $fStart + 0.001 Then
                $iLane = $j
                ExitLoop
            EndIf
        Next
        If $iLane = -1 Then
            If $iLanes >= $TL_MAX_LANES Then ContinueLoop ; garde-fou
            $iLane = $iLanes
            $aName[$iLane] = $sName
            $aKind[$iLane] = 0
            $iLanes += 1
        EndIf
        $aEnd[$iLane] = $fStart + $fDur
        _Timeline_AddBlock($iLane, $fStart, $fDur, 0, $g_aDetections[$i][4], _
                $g_aDetections[$i][5], $sName)
    Next

    ; Inconnus (piste dédiée, sous-pistes si chevauchement)
    For $i = 0 To $g_iUnknowns - 1
        $fStart = $g_aUnknowns[$i][0]
        $fDur = $g_aUnknowns[$i][1]
        $iLane = -1
        For $j = 0 To $iLanes - 1
            If $aKind[$j] = 1 And $aEnd[$j] <= $fStart + 0.001 Then
                $iLane = $j
                ExitLoop
            EndIf
        Next
        If $iLane = -1 Then
            If $iLanes >= $TL_MAX_LANES Then ContinueLoop
            $iLane = $iLanes
            $aName[$iLane] = "INCONNU"
            $aKind[$iLane] = 1
            $iLanes += 1
        EndIf
        $aEnd[$iLane] = $fStart + $fDur
        _Timeline_AddBlock($iLane, $fStart, $fDur, 1, $g_aUnknowns[$i][2], 0, "INCONNU")
    Next

    ; Publier les pistes
    $g_iTlLanes = $iLanes
    ReDim $g_aTlLaneName[$iLanes]
    ReDim $g_aTlLaneKind[$iLanes]
    ReDim $g_aTlLaneColor[$iLanes]
    For $j = 0 To $iLanes - 1
        $g_aTlLaneName[$j] = $aName[$j]
        $g_aTlLaneKind[$j] = $aKind[$j]
        $g_aTlLaneColor[$j] = Timeline_ColorIndex($aName[$j])
    Next
EndFunc

Func _Timeline_AddBlock($iLane, $fStart, $fDur, $iKind, $fDb, $fConf, $sName)
    $g_aTlBlocks[$g_iTlBlocks][0] = $iLane
    $g_aTlBlocks[$g_iTlBlocks][1] = $fStart
    $g_aTlBlocks[$g_iTlBlocks][2] = $fDur
    $g_aTlBlocks[$g_iTlBlocks][3] = $iKind
    $g_aTlBlocks[$g_iTlBlocks][4] = $fDb
    $g_aTlBlocks[$g_iTlBlocks][5] = $fConf
    $g_aTlBlocks[$g_iTlBlocks][6] = $sName
    $g_iTlBlocks += 1
EndFunc

; Hauteur de ligne + nombre de pistes visibles pour un rect donné.
Func Timeline_LayoutRows($aRect, ByRef $iRowH, ByRef $iVisible)
    $iRowH = 30
    If $g_iTlLanes > 0 And $g_iTlLanes * $iRowH > $aRect[3] Then $iRowH = Int($aRect[3] / $g_iTlLanes)
    If $iRowH < 20 Then $iRowH = 20
    $iVisible = Int($aRect[3] / $iRowH)
    If $iVisible > $g_iTlLanes Then $iVisible = $g_iTlLanes
EndFunc

; Bloc sous (x, y) dans la zone blocs, pour la vue donnée. -1 si aucun.
Func Timeline_HitBlock($iX, $iY, $aRect, $fViewStart, $fViewDur)
    If $g_iTlBlocks = 0 Or $fViewDur <= 0 Then Return -1
    Local $iRowH, $iVisible
    Timeline_LayoutRows($aRect, $iRowH, $iVisible)
    Local $iLane = Int(($iY - $aRect[1]) / $iRowH)
    If $iLane < 0 Or $iLane >= $iVisible Then Return -1
    Local $fT = $fViewStart + ($iX - $aRect[0]) * $fViewDur / $aRect[2]
    Local $i
    For $i = 0 To $g_iTlBlocks - 1
        If $g_aTlBlocks[$i][0] = $iLane And $fT >= $g_aTlBlocks[$i][1] _
                And $fT < $g_aTlBlocks[$i][1] + $g_aTlBlocks[$i][2] Then Return $i
    Next
    Return -1
EndFunc
