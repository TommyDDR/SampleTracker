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

; Interactions waveform (phase 3)
Global $g_iWheelDelta = 0       ; accumulé par WM_MOUSEWHEEL, consommé dans la boucle
Global $g_iWheelDeltaCtrl = 0   ; idem avec Ctrl enfoncé (zoom amplitude)
Global $g_bWaveDragging = False
Global $g_iDragStartX = 0
Global $g_fDragStartView = 0
Global $g_hLastClickTimer = 0   ; détection double-clic
Global $g_iLastClickX = -1000
Global $g_iLastClickY = -1000
Global $g_iDragRefX = 0         ; origine x du rect où le drag a commencé
Global $g_iDragRefW = 1         ; largeur du rect où le drag a commencé (sec/px)

; Survol timeline (phase 6)
Global $g_iHoverBlock = -1
Global $g_iHoverX = 0
Global $g_iHoverY = 0

; Redimensionnement des zones par poignée
Global $g_iHoverSplitter = -1   ; $SPLIT_NONE
Global $g_iDragSplitter = -1
Global $g_bCursorSizeNS = False ; curseur souris actuellement en double flèche

; Survol bibliothèque (prévisualisation au clic)
Global $g_iHoverSample = -1
Global $g_iSamplesScroll = 0    ; première ligne affichée dans la grille
Global $g_bSamplesMore = False  ; ligne « + N autres… » survolée

; Survol d'un libellé de piste dans la timeline (nom complet en infobulle)
Global $g_iHoverLane = -1

; Dernier sample joué : reste mis en évidence jusqu'au suivant
Global $g_sLastPlayed = ""

; Analyse (phase 5)
Global $g_bAnalyzing = False
Global $g_hAnalyzeTimer = 0
Global $g_iResultsVersion = 0   ; incrémenté quand les résultats changent (clé cache UI)

; Message de statut (barre du bas)
Global $g_sStatusText = ""
Global $g_iStatusKind = 0       ; 0 info, 1 succès, 2 erreur
Global $g_hStatusTimer = 0
