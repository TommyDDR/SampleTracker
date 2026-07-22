; ===========================================================================
; Test phase 6 : affectation des pistes (Timeline.au3), sans UI.
; Lancement : AutoIt3.exe tests\Phase6Test.au3   (exit 0 = PASS)
; Fabrique des détections/inconnus en mémoire, vérifie : une piste par nom,
; sous-piste si chevauchement du même sample, piste INCONNU, hit-test.
; ===========================================================================

#include "..\src\Engine.au3"
#include "..\src\Timeline.au3"

Opt("MustDeclareVars", 1)

Global $g_iFailures = 0

Main()

Func Main()
    ; Détections (triées par start, comme le moteur) :
    ; A@0 d1 ; B@0.5 d1 ; A@2 d1 (réutilise la piste A) ; A@2.5 d1 (chevauche → sous-piste)
    ReDim $g_aDetections[4][6]
    _Det(0, "A.wav", 0.0, 1.0, -2.0, 0.99)
    _Det(1, "B.wav", 0.5, 1.0, -6.0, 0.95)
    _Det(2, "A.wav", 2.0, 1.0, -3.0, 0.98)
    _Det(3, "A.wav", 2.5, 1.0, -4.0, 0.97)
    $g_iDetections = 4
    ReDim $g_aUnknowns[1][3]
    $g_aUnknowns[0][0] = 5.0
    $g_aUnknowns[0][1] = 0.5
    $g_aUnknowns[0][2] = -18.0
    $g_iUnknowns = 1

    Timeline_Rebuild()

    Assert($g_iTlLanes = 4, "4 pistes (obtenu " & $g_iTlLanes & ")")
    Assert($g_aTlLaneName[0] = "A.wav" And $g_aTlLaneKind[0] = 0, "piste 0 = A.wav")
    Assert($g_aTlLaneName[1] = "B.wav" And $g_aTlLaneKind[1] = 0, "piste 1 = B.wav")
    Assert($g_aTlLaneName[2] = "A.wav" And $g_aTlLaneKind[2] = 0, "piste 2 = sous-piste A.wav (chevauchement)")
    Assert($g_aTlLaneName[3] = "INCONNU" And $g_aTlLaneKind[3] = 1, "piste 3 = INCONNU")
    Assert($g_aTlLaneColor[0] = $g_aTlLaneColor[2], "couleur stable par nom (A = sous-piste A)")

    Assert($g_iTlBlocks = 5, "5 blocs (obtenu " & $g_iTlBlocks & ")")
    Assert($g_aTlBlocks[0][0] = 0, "A@0 sur piste 0")
    Assert($g_aTlBlocks[1][0] = 1, "B@0.5 sur piste 1")
    Assert($g_aTlBlocks[2][0] = 0, "A@2 réutilise la piste 0")
    Assert($g_aTlBlocks[3][0] = 2, "A@2.5 sur la sous-piste 2")
    Assert($g_aTlBlocks[4][0] = 3 And $g_aTlBlocks[4][3] = 1, "INCONNU@5 sur piste 3, kind 1")

    ; Hit-test : rect 400x120, vue 0..6 s → rowH 30, 4 pistes visibles
    Local $aRect[4] = [0, 0, 400, 120]
    Local $iRowH, $iVisible
    Timeline_LayoutRows($aRect, $iRowH, $iVisible)
    Assert($iRowH = 30 And $iVisible = 4, "layout rows 30 px / 4 visibles")
    ; t=2.5 y=15 → piste 0 → bloc A@2 (index 2)
    Assert(Timeline_HitBlock(Int(2.5 / 6 * 400), 15, $aRect, 0, 6) = 2, "hit A@2 sur piste 0")
    ; t=2.7 y=75 → piste 2 → bloc A@2.5 (index 3)
    Assert(Timeline_HitBlock(Int(2.7 / 6 * 400), 75, $aRect, 0, 6) = 3, "hit A@2.5 sur sous-piste")
    ; t=5.2 y=105 → piste 3 → bloc INCONNU (index 4)
    Assert(Timeline_HitBlock(Int(5.2 / 6 * 400), 105, $aRect, 0, 6) = 4, "hit INCONNU")
    ; t=4.0 piste 0 → rien
    Assert(Timeline_HitBlock(Int(4.0 / 6 * 400), 15, $aRect, 0, 6) = -1, "pas de bloc à t=4 piste 0")

    ; Clear
    Timeline_Clear()
    Assert($g_iTlLanes = 0 And $g_iTlBlocks = 0, "Timeline_Clear")

    If $g_iFailures > 0 Then
        ConsoleWrite("FAIL : " & $g_iFailures & " échec(s)" & @CRLF)
        Exit 1
    EndIf
    ConsoleWrite("PASS" & @CRLF)
    Exit 0
EndFunc

Func _Det($i, $sName, $fStart, $fDur, $fDb, $fConf)
    $g_aDetections[$i][0] = $sName
    $g_aDetections[$i][1] = $fStart
    $g_aDetections[$i][2] = $fDur
    $g_aDetections[$i][3] = 10 ^ ($fDb / 20)
    $g_aDetections[$i][4] = $fDb
    $g_aDetections[$i][5] = $fConf
EndFunc

Func Assert($bCond, $sLabel)
    If $bCond Then
        ConsoleWrite("  ok  " & $sLabel & @CRLF)
    Else
        ConsoleWrite("  KO  " & $sLabel & @CRLF)
        $g_iFailures += 1
    EndIf
EndFunc
