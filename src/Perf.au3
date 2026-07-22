#include-once

; ---------------------------------------------------------------------------
; Profiler par sections (doc rendu §10) — coût nul quand désactivé.
; Toggle F3 : moyennes par section affichées dans le titre toutes les 30 frames.
; ---------------------------------------------------------------------------

Global Const $PERF_INPUT = 0
Global Const $PERF_UI = 1
Global Const $PERF_PRESENT = 2
Global Const $PERF_FRAME = 3
Global Const $PERF_SECTION_COUNT = 4

Global $g_aPerfNames[4] = ["input", "ui", "present", "frame"]
Global $g_aPerfTimers[4]
Global $g_aPerfAccum[4] = [0, 0, 0, 0]
Global $g_iPerfFrames = 0
Global $g_bPerfEnabled = False
Global $g_bPerfKeyDown = False

Func Perf_Begin($iSection)
    If Not $g_bPerfEnabled Then Return
    $g_aPerfTimers[$iSection] = TimerInit()
EndFunc

Func Perf_End($iSection)
    If Not $g_bPerfEnabled Then Return
    $g_aPerfAccum[$iSection] += TimerDiff($g_aPerfTimers[$iSection])
EndFunc

Func Perf_Reset()
    Local $i
    For $i = 0 To $PERF_SECTION_COUNT - 1
        $g_aPerfAccum[$i] = 0
    Next
    $g_iPerfFrames = 0
EndFunc

; Appelé en fin de frame avec le timer de début de frame.
Func Perf_FrameDone($hFrameTimer)
    If Not $g_bPerfEnabled Then Return
    $g_aPerfAccum[$PERF_FRAME] += TimerDiff($hFrameTimer)
    $g_iPerfFrames += 1
    If $g_iPerfFrames < 30 Then Return
    Local $sTitle = "SampleTracker"
    Local $i
    For $i = 0 To $PERF_SECTION_COUNT - 1
        $sTitle &= StringFormat(" | %s %.2f ms", $g_aPerfNames[$i], $g_aPerfAccum[$i] / $g_iPerfFrames)
        $g_aPerfAccum[$i] = 0
    Next
    WinSetTitle($g_hGui, "", $sTitle)
    $g_iPerfFrames = 0
EndFunc
