# SampleTracker

Logiciel Windows d'analyse et de décomposition audio. Analyse un fichier audio/vidéo
composé de petits samples connus (mixés uniquement par gain, sans pitch/vitesse/effets)
et affiche la composition détectée sous forme de pistes sur une timeline type MAO.

## Architecture

```
Interface AutoIt (GUI, waveform, timeline, blocs)
    ├── ffmpeg.exe        → décodage MP3/WAV + extraction audio MP4 vers PCM
    └── engine.exe        → moteur d'analyse (corrélation FFT + matching pursuit)
                            sortie : JSON (détections, gains, confiance, inconnus)
```

Le rendu de l'interface suit les pratiques décrites dans
[pratiques-rendu-performant.md](pratiques-rendu-performant.md) : backbuffer DIB 32bpp,
un seul blit de présentation par frame, `WM_ERASEBKGND` intercepté, caches à clé,
registre de disposers GDI+, profiler intégré.

## Roadmap (une branche + une MR par phase)

| Phase | Branche | Contenu |
|---|---|---|
| 1 | `feature/phase-1-interface` | Squelette GUI : fenêtre, zones, drag & drop, boutons, boucle de rendu |
| 2 | `feature/phase-2-ffmpeg` | Intégration ffmpeg : décodage, extraction audio MP4 |
| 3 | `feature/phase-3-waveform` | Affichage waveform + règle temporelle + zoom |
| 4 | `feature/phase-4-moteur` | Moteur d'analyse CLI (corrélation, matching pursuit, JSON) |
| 5 | `feature/phase-5-connexion` | Lancement moteur depuis la GUI, progression, parsing JSON |
| 6 | `feature/phase-6-timeline` | Timeline MAO : blocs multi-pistes, tooltips, blocs INCONNU |
| 7 | `feature/phase-7-optimisation` | Cache signatures, pré-filtre spectral, réglages seuils |

## Lancement

Prérequis :
- AutoIt 3.3.16+
- ffmpeg : `bin\ffmpeg.exe` (non versionné — télécharger un build statique,
  ex. gyan.dev "essentials") ou disponible dans le PATH
- Python 3.10+ avec numpy (moteur d'analyse, phases 4+)

```
AutoIt3.exe SampleTracker.au3
```

## Tests

```
AutoIt3.exe tests\Phase2Test.au3
AutoIt3.exe tests\Phase3Test.au3
AutoIt3.exe tests\Phase5Test.au3
AutoIt3.exe tests\Phase6Test.au3
python engine\test_engine.py
```

Exit 0 = PASS, 1 = FAIL, 2 = SKIP (ffmpeg absent). Phase 2 : extraction MP4 →
PCM vérifié via l'en-tête WAV. Phase 3 : pics waveform (silence + carré 440 Hz),
mipmaps, zoom et clamps de vue. Phase 4 : mix synthétique à vérité terrain
connue (superpositions, son inconnu, ré-encodage MP3).

## Moteur d'analyse (phase 4)

```
python engine\analyze.py --source mix.wav --samples DOSSIER --output result.json
                         [--threshold 0.6] [--max-iter 200] [--progress]
```

Corrélation croisée normalisée par FFT + matching pursuit : meilleur candidat,
gain estimé par moindres carrés, soustraction du résidu, itération. Zones du
résidu au-dessus de `--floor-db` (défaut −40 dBFS) → blocs INCONNU. Sortie
JSON : détections (sample, start, duration, gain, gain_db, confidence),
inconnus (start, duration, rms_db), résidu global.

Précision mesurée (mix synthétique) : position < 10 ms, gain < 0.3 dB (WAV)
/ < 0.8 dB (MP3 192k), superpositions résolues, zéro fausse détection.

## Utilisation (phase 1)

- Glisser-déposer un fichier MP3/WAV/MP4 n'importe où dans la fenêtre → chargé comme source.
- Glisser-déposer un dossier → chargé comme bibliothèque de samples (scan `*.mp3`/`*.wav`).
- Boutons : « Ouvrir source », « Dossier samples ».
- « Analyser la composition » : lance le moteur en arrière-plan, barre de
  progression, puis timeline MAO : une piste par sample (sous-piste si deux
  occurrences se chevauchent), blocs colorés (couleur stable par nom), blocs
  INCONNU hachurés en rouge, tooltip au survol (début, durée, gain, confiance).
  Zoom/pan synchronisés avec la waveform (molette + glisser + double-clic
  aussi actifs sur la zone de blocs).
- Waveform (phase 3) : calculée en arrière-plan après extraction ; molette = zoom
  autour du curseur, glisser = déplacement, double-clic = vue complète.
- `F3` : profiler (temps par section dans le titre de la fenêtre).

Note : le drag & drop depuis l'Explorateur ne fonctionne pas si l'application est
lancée en administrateur (isolation UIPI de Windows).
