#include-once

; ---------------------------------------------------------------------------
; Intégration ffmpeg : localisation du binaire et extraction audio asynchrone
; (MP3/WAV/MP4 → PCM WAV mono 44.1 kHz 16 bits, format uniforme pour le moteur).
; Aucune dépendance UI : module testable en CLI.
; ---------------------------------------------------------------------------

Global $g_sFfmpegPath = ""
Global $g_iFfmpegPid = 0
Global $g_sFfmpegLog = ""

; Cherche bin\ffmpeg.exe à côté du script, sinon dans le PATH. "" si introuvable.
Func Ffmpeg_Locate()
    If $g_sFfmpegPath <> "" Then Return $g_sFfmpegPath
    Local $sLocal = @ScriptDir & "\bin\ffmpeg.exe"
    If FileExists($sLocal) Then
        $g_sFfmpegPath = $sLocal
        Return $g_sFfmpegPath
    EndIf
    If RunWait(@ComSpec & " /c ffmpeg -version >nul 2>&1", "", @SW_HIDE) = 0 Then
        $g_sFfmpegPath = "ffmpeg"
    EndIf
    Return $g_sFfmpegPath
EndFunc

; Lance l'extraction en arrière-plan. stderr redirigé vers $sLogFile.
; @error : 1 = ffmpeg introuvable, 2 = échec lancement.
Func Ffmpeg_StartExtract($sSource, $sOutWav, $sLogFile)
    Local $sFf = Ffmpeg_Locate()
    If $sFf = "" Then Return SetError(1, 0, 0)
    FileDelete($sOutWav)
    $g_sFfmpegLog = $sLogFile
    Local $sCmd = @ComSpec & ' /c ""' & $sFf & '" -y -hide_banner -i "' & $sSource _
            & '" -vn -ac 1 -ar 44100 -c:a pcm_s16le "' & $sOutWav & '" 2>"' & $sLogFile & '""'
    $g_iFfmpegPid = Run($sCmd, "", @SW_HIDE)
    If $g_iFfmpegPid = 0 Then Return SetError(2, 0, 0)
    Return 1
EndFunc

Func Ffmpeg_IsRunning()
    Return $g_iFfmpegPid <> 0 And ProcessExists($g_iFfmpegPid)
EndFunc

; Tue cmd + ffmpeg enfant (arbre complet).
Func Ffmpeg_Cancel()
    If Ffmpeg_IsRunning() Then
        RunWait(@ComSpec & " /c taskkill /PID " & $g_iFfmpegPid & " /T /F >nul 2>&1", "", @SW_HIDE)
    EndIf
    $g_iFfmpegPid = 0
EndFunc

; Dernière ligne non vide du log stderr (ligne d'erreur décisive de ffmpeg).
Func Ffmpeg_LastErrorLine()
    Local $sLog = FileRead($g_sFfmpegLog)
    If @error Then Return "erreur ffmpeg inconnue"
    Local $aLines = StringSplit(StringStripCR($sLog), @LF)
    Local $i, $sLine
    For $i = $aLines[0] To 1 Step -1
        $sLine = StringStripWS($aLines[$i], 3)
        If $sLine <> "" Then Return $sLine
    Next
    Return "erreur ffmpeg inconnue"
EndFunc
