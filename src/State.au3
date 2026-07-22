#include-once

; ---------------------------------------------------------------------------
; État global de l'application (phase 1)
; ---------------------------------------------------------------------------

Global $g_hGui = 0
Global $g_bRunning = True

; Fichier source chargé (chemin complet, vide si aucun)
Global $g_sSourcePath = ""

; Extraction audio (phase 2)
Global $g_sSourceWav = ""       ; PCM extrait prêt pour l'analyse ("" si pas prêt)
Global $g_fSourceDuration = 0   ; durée en secondes
Global $g_iSourceRate = 0       ; Hz
Global $g_bExtracting = False
Global $g_hExtractTimer = 0     ; anime les points de suspension
Global $g_sWorkDir = ""         ; dossier temporaire (WAV extrait, logs)

; Bibliothèque de samples
Global $g_sSamplesDir = ""
Global $g_aSampleFiles[0] ; noms de fichiers (0-based), triés

; UI
Global $g_iHoverButton = -1     ; index bouton survolé, -1 sinon
Global $g_sUiCacheKey = ""      ; clé du cache UI plein écran (§7.3 du doc rendu)

; Message de statut (barre du bas)
Global $g_sStatusText = ""
Global $g_iStatusKind = 0       ; 0 info, 1 succès, 2 erreur
Global $g_hStatusTimer = 0
