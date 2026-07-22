#include-once

; ---------------------------------------------------------------------------
; Lecture d'en-tête WAV (RIFF/WAVE) : format, durée et position des données,
; sans charger les données.
; Aucune dépendance UI : module testable en CLI.
; ---------------------------------------------------------------------------

; Parcourt les chunks RIFF. Retourne la durée en secondes, renseigne format
; et position du chunk data par référence.
; @error : 1 = ouverture, 2 = fichier trop court, 3 = pas un WAV, 4 = en-tête incomplet.
Func Wav_ReadInfoEx($sPath, ByRef $iRate, ByRef $iChannels, ByRef $iBits, ByRef $iDataOffset, ByRef $iDataSize)
    $iRate = 0
    $iChannels = 0
    $iBits = 0
    $iDataOffset = 0
    $iDataSize = 0
    Local $hFile = FileOpen($sPath, 16) ; binaire
    If $hFile = -1 Then Return SetError(1, 0, 0)
    Local $bHdr = FileRead($hFile, 12)
    If @error Or BinaryLen($bHdr) < 12 Then
        FileClose($hFile)
        Return SetError(2, 0, 0)
    EndIf
    If BinaryToString(BinaryMid($bHdr, 1, 4)) <> "RIFF" _
            Or BinaryToString(BinaryMid($bHdr, 9, 4)) <> "WAVE" Then
        FileClose($hFile)
        Return SetError(3, 0, 0)
    EndIf
    Local $bChunk, $sId, $iSize, $bFmt
    While 1
        $bChunk = FileRead($hFile, 8)
        If @error Or BinaryLen($bChunk) < 8 Then ExitLoop
        $sId = BinaryToString(BinaryMid($bChunk, 1, 4))
        $iSize = Int(BinaryMid($bChunk, 5, 4)) ; little-endian
        If $sId = "fmt " Then
            $bFmt = FileRead($hFile, $iSize + Mod($iSize, 2))
            If @error Or BinaryLen($bFmt) < 16 Then ExitLoop
            $iChannels = Int(BinaryMid($bFmt, 3, 2))
            $iRate = Int(BinaryMid($bFmt, 5, 4))
            $iBits = Int(BinaryMid($bFmt, 15, 2))
        ElseIf $sId = "data" Then
            $iDataOffset = FileGetPos($hFile)
            $iDataSize = $iSize
            ExitLoop
        Else
            FileSetPos($hFile, $iSize + Mod($iSize, 2), 1) ; chunks alignés sur 2 octets
        EndIf
    WEnd
    FileClose($hFile)
    If $iRate = 0 Or $iChannels = 0 Or $iBits = 0 Or $iDataSize = 0 Then Return SetError(4, 0, 0)
    Return $iDataSize / ($iRate * $iChannels * ($iBits / 8))
EndFunc

; Variante simple : durée + format uniquement.
Func Wav_ReadInfo($sPath, ByRef $iRate, ByRef $iChannels, ByRef $iBits)
    Local $iDataOffset, $iDataSize
    Local $fDuration = Wav_ReadInfoEx($sPath, $iRate, $iChannels, $iBits, $iDataOffset, $iDataSize)
    If @error Then Return SetError(@error, 0, 0)
    Return $fDuration
EndFunc
