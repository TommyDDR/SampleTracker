#include-once

; ---------------------------------------------------------------------------
; Waveform : calcul asynchrone des pics (min/max par bucket) + mipmaps pour
; l'agrégation au zoom, et état de la vue (start/durée).
; Le calcul est étalé sur plusieurs frames (WAVE_BUCKETS_PER_FRAME par appel
; de Waveform_Step) : l'UI ne freeze jamais.
; Aucune dépendance UI : module testable en CLI.
; ---------------------------------------------------------------------------

Global Const $WAVE_BUCKETS_PER_SEC = 50   ; résolution de base : 20 ms par bucket
Global Const $WAVE_PROBES = 32            ; échantillons sondés par bucket (sous-échantillonnage)
Global Const $WAVE_BUCKETS_PER_FRAME = 100
Global Const $WAVE_MIN_VIEW_DUR = 0.05    ; zoom max : 50 ms visibles

; Données de calcul
Global $g_tWaveBytes = 0        ; struct byte[] propriétaire des données PCM
Global $g_tWaveShorts = 0       ; alias short[] sur le même buffer
Global $g_iWaveSampleCount = 0
Global $g_iWaveRate = 0
Global $g_fWaveDuration = 0
Global $g_iWaveBuckets = 0
Global $g_fWaveSamplesPerBucket = 0
Global $g_iWaveCursor = 0       ; prochain bucket à calculer
Global $g_bWaveComputing = False
Global $g_bWaveReady = False
Global $g_iWaveVersion = 0      ; incrémenté quand les pics changent (clé de cache UI)

; Pics niveau 0 (base)
Global $g_aWaveMin[0]
Global $g_aWaveMax[0]

; Mipmaps : niveaux /2 successifs, concaténés dans un tableau plat
Global $g_iWaveMipLevels = 0
Global $g_aWaveMipOffset[0]     ; offset du niveau dans le tableau plat
Global $g_aWaveMipCount[0]      ; nombre de buckets du niveau
Global $g_aWaveMipMin[0]
Global $g_aWaveMipMax[0]

; Vue (fenêtre temporelle affichée)
Global $g_fViewStart = 0
Global $g_fViewDur = 0
Global $g_fWaveYZoom = 1        ; zoom amplitude (axe Y), 1 = pleine échelle

Func Waveform_Reset()
    $g_tWaveShorts = 0
    $g_tWaveBytes = 0
    $g_iWaveSampleCount = 0
    $g_iWaveRate = 0
    $g_fWaveDuration = 0
    $g_iWaveBuckets = 0
    $g_iWaveCursor = 0
    $g_bWaveComputing = False
    $g_bWaveReady = False
    $g_iWaveMipLevels = 0
    ReDim $g_aWaveMin[0]
    ReDim $g_aWaveMax[0]
    $g_iWaveVersion += 1
EndFunc

; Charge le PCM (WAV mono 16 bits) et démarre le calcul asynchrone.
; @error : 1 = format inattendu, 2 = ouverture, 3 = données vides.
Func Waveform_Start($sWavPath)
    Waveform_Reset()
    Local $iRate, $iChannels, $iBits, $iDataOffset, $iDataSize
    Wav_ReadInfoEx($sWavPath, $iRate, $iChannels, $iBits, $iDataOffset, $iDataSize)
    If @error Or $iBits <> 16 Or $iChannels <> 1 Then Return SetError(1, 0, 0)
    Local $hFile = FileOpen($sWavPath, 16)
    If $hFile = -1 Then Return SetError(2, 0, 0)
    FileSetPos($hFile, $iDataOffset, 0)
    Local $bData = FileRead($hFile, $iDataSize)
    FileClose($hFile)
    Local $iCount = Int(BinaryLen($bData) / 2)
    If $iCount < 1 Then Return SetError(3, 0, 0)

    $g_tWaveBytes = DllStructCreate("byte[" & BinaryLen($bData) & "]")
    DllStructSetData($g_tWaveBytes, 1, $bData)
    $g_tWaveShorts = DllStructCreate("short[" & $iCount & "]", DllStructGetPtr($g_tWaveBytes))

    $g_iWaveSampleCount = $iCount
    $g_iWaveRate = $iRate
    $g_fWaveDuration = $iCount / $iRate
    $g_iWaveBuckets = Int($g_fWaveDuration * $WAVE_BUCKETS_PER_SEC)
    If $g_iWaveBuckets < 10 Then $g_iWaveBuckets = 10
    $g_fWaveSamplesPerBucket = $iCount / $g_iWaveBuckets
    ReDim $g_aWaveMin[$g_iWaveBuckets]
    ReDim $g_aWaveMax[$g_iWaveBuckets]
    $g_iWaveCursor = 0
    $g_bWaveComputing = True
    Waveform_ResetView()
    Return 1
EndFunc

; Appelé chaque frame : calcule un lot de buckets. Coût nul hors calcul.
Func Waveform_Step()
    If Not $g_bWaveComputing Then Return
    Local $iEnd = $g_iWaveCursor + $WAVE_BUCKETS_PER_FRAME
    If $iEnd > $g_iWaveBuckets Then $iEnd = $g_iWaveBuckets
    Local $i, $iBase, $iCount, $iMin, $iMax, $v, $fStep, $fJ
    For $i = $g_iWaveCursor To $iEnd - 1
        $iBase = Int($i * $g_fWaveSamplesPerBucket)
        $iCount = Int($g_fWaveSamplesPerBucket) + 1
        If $iBase + $iCount > $g_iWaveSampleCount Then $iCount = $g_iWaveSampleCount - $iBase
        If $iCount < 1 Then
            $g_aWaveMin[$i] = 0
            $g_aWaveMax[$i] = 0
            ContinueLoop
        EndIf
        $iMin = 32767
        $iMax = -32768
        $fStep = $iCount / $WAVE_PROBES
        If $fStep < 1 Then $fStep = 1
        $fJ = 0
        While $fJ < $iCount
            $v = DllStructGetData($g_tWaveShorts, 1, $iBase + Int($fJ) + 1)
            If $v < $iMin Then $iMin = $v
            If $v > $iMax Then $iMax = $v
            $fJ += $fStep
        WEnd
        $g_aWaveMin[$i] = $iMin
        $g_aWaveMax[$i] = $iMax
    Next
    $g_iWaveCursor = $iEnd
    If $g_iWaveCursor >= $g_iWaveBuckets Then
        _Waveform_BuildMips()
        $g_bWaveComputing = False
        $g_bWaveReady = True
        $g_iWaveVersion += 1
        ; Libérer le PCM : seuls les pics servent à l'affichage
        $g_tWaveShorts = 0
        $g_tWaveBytes = 0
    EndIf
EndFunc

Func Waveform_GetBucketDur()
    If $g_iWaveBuckets = 0 Then Return 0
    Return $g_fWaveDuration / $g_iWaveBuckets
EndFunc

Func Waveform_Progress()
    If $g_iWaveBuckets = 0 Then Return 0
    Return Int(100 * $g_iWaveCursor / $g_iWaveBuckets)
EndFunc

; Construit les niveaux /2 (agrégation min/min, max/max) dans un tableau plat.
Func _Waveform_BuildMips()
    ; Comptage des niveaux et de la taille totale
    Local $iLevels = 1
    Local $n = $g_iWaveBuckets
    Local $iTotal = $n
    While $n > 2 And $iLevels < 20
        $n = Int(($n + 1) / 2)
        $iTotal += $n
        $iLevels += 1
    WEnd
    $g_iWaveMipLevels = $iLevels
    ReDim $g_aWaveMipOffset[$iLevels]
    ReDim $g_aWaveMipCount[$iLevels]
    ReDim $g_aWaveMipMin[$iTotal]
    ReDim $g_aWaveMipMax[$iTotal]

    ; Niveau 0 : copie de la base
    $g_aWaveMipOffset[0] = 0
    $g_aWaveMipCount[0] = $g_iWaveBuckets
    Local $i
    For $i = 0 To $g_iWaveBuckets - 1
        $g_aWaveMipMin[$i] = $g_aWaveMin[$i]
        $g_aWaveMipMax[$i] = $g_aWaveMax[$i]
    Next

    ; Niveaux suivants : réduction pairwise du niveau précédent
    Local $iLevel, $iPrevOff, $iPrevCount, $iOff, $iCount, $iSrc, $iMin, $iMax
    For $iLevel = 1 To $iLevels - 1
        $iPrevOff = $g_aWaveMipOffset[$iLevel - 1]
        $iPrevCount = $g_aWaveMipCount[$iLevel - 1]
        $iOff = $iPrevOff + $iPrevCount
        $iCount = Int(($iPrevCount + 1) / 2)
        $g_aWaveMipOffset[$iLevel] = $iOff
        $g_aWaveMipCount[$iLevel] = $iCount
        For $i = 0 To $iCount - 1
            $iSrc = $iPrevOff + $i * 2
            $iMin = $g_aWaveMipMin[$iSrc]
            $iMax = $g_aWaveMipMax[$iSrc]
            If $i * 2 + 1 < $iPrevCount Then
                If $g_aWaveMipMin[$iSrc + 1] < $iMin Then $iMin = $g_aWaveMipMin[$iSrc + 1]
                If $g_aWaveMipMax[$iSrc + 1] > $iMax Then $iMax = $g_aWaveMipMax[$iSrc + 1]
            EndIf
            $g_aWaveMipMin[$iOff + $i] = $iMin
            $g_aWaveMipMax[$iOff + $i] = $iMax
        Next
    Next
EndFunc

; Pics min/max sur l'intervalle [t0, t1] : choisit le niveau de mipmap où
; l'intervalle couvre <= 2-3 buckets, puis agrège (coût constant par colonne).
Func Waveform_GetColumnPeaks($fT0, $fT1, ByRef $iMin, ByRef $iMax)
    $iMin = 0
    $iMax = 0
    If Not $g_bWaveReady Or $g_iWaveMipLevels = 0 Then Return
    Local $fBucketDur = $g_fWaveDuration / $g_iWaveBuckets
    Local $fSpan = ($fT1 - $fT0) / $fBucketDur
    Local $iLevel = 0
    Local $fLevelDur = $fBucketDur
    While $fSpan > 2 And $iLevel < $g_iWaveMipLevels - 1
        $fSpan /= 2
        $fLevelDur *= 2
        $iLevel += 1
    WEnd
    Local $iOff = $g_aWaveMipOffset[$iLevel]
    Local $iCount = $g_aWaveMipCount[$iLevel]
    Local $i0 = Int($fT0 / $fLevelDur)
    Local $i1 = Int($fT1 / $fLevelDur)
    If $i0 < 0 Then $i0 = 0
    If $i1 >= $iCount Then $i1 = $iCount - 1
    If $i0 > $i1 Then Return
    $iMin = 32767
    $iMax = -32768
    Local $i
    For $i = $i0 To $i1
        If $g_aWaveMipMin[$iOff + $i] < $iMin Then $iMin = $g_aWaveMipMin[$iOff + $i]
        If $g_aWaveMipMax[$iOff + $i] > $iMax Then $iMax = $g_aWaveMipMax[$iOff + $i]
    Next
EndFunc

; --- Vue (zoom / pan) ------------------------------------------------------

Func Waveform_ResetView()
    $g_fViewStart = 0
    $g_fViewDur = $g_fWaveDuration
    $g_fWaveYZoom = 1
EndFunc

; Zoom amplitude, clampé [1, 100].
Func Waveform_ZoomY($fFactor)
    $g_fWaveYZoom *= $fFactor
    If $g_fWaveYZoom < 1 Then $g_fWaveYZoom = 1
    If $g_fWaveYZoom > 100 Then $g_fWaveYZoom = 100
EndFunc

; Clamp la vue dans [0, durée].
Func Waveform_SetView($fStart, $fDur)
    If $fDur < $WAVE_MIN_VIEW_DUR Then $fDur = $WAVE_MIN_VIEW_DUR
    If $fDur > $g_fWaveDuration Then $fDur = $g_fWaveDuration
    If $fStart < 0 Then $fStart = 0
    If $fStart + $fDur > $g_fWaveDuration Then $fStart = $g_fWaveDuration - $fDur
    $g_fViewStart = $fStart
    $g_fViewDur = $fDur
EndFunc

; Zoom autour d'un temps ancre (position sous le curseur invariante).
Func Waveform_Zoom($fFactor, $fAnchor)
    If $g_fViewDur = 0 Then Return
    Local $fNewDur = $g_fViewDur * $fFactor
    If $fNewDur < $WAVE_MIN_VIEW_DUR Then $fNewDur = $WAVE_MIN_VIEW_DUR
    If $fNewDur > $g_fWaveDuration Then $fNewDur = $g_fWaveDuration
    Local $fNewStart = $fAnchor - ($fAnchor - $g_fViewStart) * ($fNewDur / $g_fViewDur)
    Waveform_SetView($fNewStart, $fNewDur)
EndFunc
