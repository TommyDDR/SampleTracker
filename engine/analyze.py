"""SampleTracker — moteur d'analyse (phase 4).

Décompose un fichier source en samples connus, sous l'hypothèse :
    source(t) = somme( gain_i * sample_i(t - t_i) )
(gain seul autorisé : pas de pitch, pas de time-stretch, pas d'effet).

Algorithme : corrélation croisée normalisée par FFT + matching pursuit
itératif (meilleur candidat, estimation du gain par moindres carrés,
soustraction, itération). Les zones du résidu au-dessus du plancher de
bruit deviennent des blocs INCONNU.

Usage :
    python analyze.py --source source.wav --samples DOSSIER --output result.json
                      [--threshold 0.6] [--max-iter 200] [--progress]

Sortie : JSON (détections, inconnus, résidu). Progression sur stdout
(`PROGRESS n` avec n en %, pour l'interface graphique).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100                  # tout le pipeline travaille en mono 44.1 kHz
BAN_RADIUS = int(0.005 * SR)  # ±5 ms : anti-redétection au même offset


# ---------------------------------------------------------------------------
# E/S audio
# ---------------------------------------------------------------------------

def find_ffmpeg() -> str:
    """bin\\ffmpeg.exe à côté du projet, sinon PATH."""
    env = os.environ.get("SAMPLETRACKER_FFMPEG")
    if env and os.path.isfile(env):
        return env
    local = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "ffmpeg.exe")
    if os.path.isfile(local):
        return local
    return "ffmpeg"


def read_wav_mono16(path: str) -> np.ndarray | None:
    """Lit un WAV PCM 16 bits mono 44.1 kHz. None si autre format."""
    try:
        with wave.open(path, "rb") as w:
            if w.getnchannels() != 1 or w.getsampwidth() != 2 or w.getframerate() != SR:
                return None
            data = w.readframes(w.getnframes())
    except (wave.Error, EOFError, OSError):
        return None
    return np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768.0


def load_audio(path: str, ffmpeg: str) -> np.ndarray:
    """Charge n'importe quel format en float32 mono 44.1 kHz (ffmpeg si besoin)."""
    direct = read_wav_mono16(path)
    if direct is not None:
        return direct
    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        result = subprocess.run(
            [ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", path,
             "-vn", "-ac", "1", "-ar", str(SR), "-c:a", "pcm_s16le", tmp],
            capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"ffmpeg a échoué sur {path} : {result.stderr.strip().splitlines()[-1:]}")
        audio = read_wav_mono16(tmp)
        if audio is None:
            raise RuntimeError(f"décodage inattendu pour {path}")
        return audio
    finally:
        os.unlink(tmp)


def list_sample_files(samples_dir: str) -> list[str]:
    """Chemins relatifs (mêmes clés que l'interface : scan récursif mp3/wav)."""
    found = []
    for root, _dirs, files in os.walk(samples_dir):
        for name in files:
            if name.lower().endswith((".mp3", ".wav")):
                full = os.path.join(root, name)
                found.append(os.path.relpath(full, samples_dir))
    found.sort()
    return found


# ---------------------------------------------------------------------------
# Détection : corrélation normalisée + matching pursuit
# ---------------------------------------------------------------------------

class SamplePrep:
    """Pré-calculs par sample : FFT conjuguée (à taille fixe) et énergie."""

    def __init__(self, name: str, data: np.ndarray, fft_size: int):
        self.name = name
        self.data = data
        self.length = len(data)
        self.energy = float(np.dot(data, data))
        self.fft_conj = np.conj(np.fft.rfft(data, fft_size))
        self.banned: list[int] = []  # offsets interdits (déjà détectés/rejetés)


def analyze(source: np.ndarray, preps: list[SamplePrep], fft_size: int,
            threshold: float, max_iter: int, min_gain: float,
            progress=lambda pct, msg: None):
    residual = source.copy()
    n_src = len(source)
    detections = []

    for iteration in range(max_iter):
        res_fft = np.fft.rfft(residual, fft_size)
        # énergie locale du résidu par somme cumulée (exacte, O(N))
        cs = np.concatenate(([0.0], np.cumsum(residual.astype(np.float64) ** 2)))

        best = None  # (score, gain, offset, prep, corr_at_peak)
        for prep in preps:
            n = prep.length
            if n > n_src or prep.energy <= 1e-9:
                continue
            corr = np.fft.irfft(res_fft * prep.fft_conj, fft_size)[: n_src - n + 1]
            local_energy = cs[n:n_src + 1] - cs[:n_src - n + 1]
            denom = np.sqrt(local_energy * prep.energy) + 1e-9
            # masquer les zones quasi silencieuses : dénominateur ~0 ferait
            # exploser le score (fausse détection dans le silence)
            score = np.where(local_energy > 1e-6 * prep.energy, corr / denom, 0.0)
            # interdire les offsets déjà consommés (±5 ms)
            for t_ban in prep.banned:
                lo = max(0, t_ban - BAN_RADIUS)
                score[lo:t_ban + BAN_RADIUS] = 0.0
            t = int(np.argmax(score))
            s = float(score[t])
            if best is None or s > best[0]:
                best = (s, float(corr[t] / prep.energy), t, prep)

        if best is None or best[0] < threshold:
            break
        score, gain, offset, prep = best
        prep.banned.append(offset)
        if gain < min_gain:
            continue  # candidat rejeté (gain négligeable), offset banni
        residual[offset:offset + prep.length] -= gain * prep.data
        detections.append({
            "sample": prep.name,
            "start": round(offset / SR, 4),
            "duration": round(prep.length / SR, 4),
            "gain": round(gain, 4),
            "gain_db": round(20 * math.log10(max(gain, 1e-6)), 2),
            "confidence": round(score, 4),
        })
        progress(None, f"iteration {iteration + 1} : {prep.name} @ {offset / SR:.3f}s "
                       f"(gain {gain:.2f}, score {score:.3f})")

    detections.sort(key=lambda d: d["start"])
    return detections, residual


def find_unknowns(residual: np.ndarray, floor_db: float = -40.0,
                  win: float = 0.05, min_dur: float = 0.08, gap: float = 0.1):
    """Segments du résidu au-dessus du plancher : blocs INCONNU."""
    hop = int(win * SR / 2)
    n_frames = max(0, (len(residual) - hop) // hop)
    if n_frames == 0:
        return []
    rms_db = np.full(n_frames, -120.0)
    for i in range(n_frames):
        frame = residual[i * hop:i * hop + 2 * hop]
        rms = float(np.sqrt(np.mean(frame ** 2)))
        if rms > 1e-6:
            rms_db[i] = 20 * math.log10(rms)
    active = rms_db > floor_db

    segments = []
    start = None
    for i, on in enumerate(active):
        if on and start is None:
            start = i
        elif not on and start is not None:
            segments.append((start, i))
            start = None
    if start is not None:
        segments.append((start, n_frames))

    # fusionner les segments séparés par un trou court
    merged = []
    for seg in segments:
        if merged and (seg[0] - merged[-1][1]) * hop / SR < gap:
            merged[-1] = (merged[-1][0], seg[1])
        else:
            merged.append(list(seg))

    unknowns = []
    for a, b in merged:
        dur = (b - a) * hop / SR
        if dur < min_dur:
            continue
        peak_db = float(np.max(rms_db[a:b]))
        unknowns.append({
            "start": round(a * hop / SR, 4),
            "duration": round(dur, 4),
            "rms_db": round(peak_db, 2),
        })
    return unknowns


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description="SampleTracker — moteur d'analyse")
    parser.add_argument("--source", required=True)
    parser.add_argument("--samples", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--threshold", type=float, default=0.6)
    parser.add_argument("--max-iter", type=int, default=200)
    parser.add_argument("--min-gain", type=float, default=0.02)
    parser.add_argument("--floor-db", type=float, default=-40.0)
    parser.add_argument("--progress", action="store_true",
                        help="émet PROGRESS n (pourcentage) sur stdout")
    args = parser.parse_args()

    def report(pct, msg=""):
        if args.progress and pct is not None:
            print(f"PROGRESS {pct}", flush=True)
        if msg:
            print(msg, flush=True)

    ffmpeg = find_ffmpeg()
    report(0, f"chargement source : {args.source}")
    source = load_audio(args.source, ffmpeg)
    report(5)

    names = list_sample_files(args.samples)
    if not names:
        print("aucun sample mp3/wav dans " + args.samples, file=sys.stderr)
        return 1

    fft_size = 1
    preps = []
    datas = []
    for i, name in enumerate(names):
        data = load_audio(os.path.join(args.samples, name), ffmpeg)
        datas.append((name, data))
        report(5 + int(25 * (i + 1) / len(names)), f"sample chargé : {name}")
    max_len = max(len(d) for _n, d in datas)
    fft_size = 1 << (len(source) + max_len - 1).bit_length()
    for name, data in datas:
        preps.append(SamplePrep(name, data, fft_size))
    report(35)

    done_iters = [0]

    def on_iter(_pct, msg):
        done_iters[0] += 1
        report(min(90, 35 + int(55 * done_iters[0] / max(args.max_iter, 1))), msg)

    detections, residual = analyze(source, preps, fft_size, args.threshold,
                                   args.max_iter, args.min_gain, on_iter)
    report(92, f"{len(detections)} détection(s)")

    unknowns = find_unknowns(residual, args.floor_db)
    res_rms = float(np.sqrt(np.mean(residual ** 2)))
    result = {
        "version": 1,
        "source": {
            "file": os.path.abspath(args.source),
            "duration": round(len(source) / SR, 4),
            "samplerate": SR,
        },
        "params": {
            "threshold": args.threshold,
            "max_iter": args.max_iter,
            "min_gain": args.min_gain,
            "floor_db": args.floor_db,
        },
        "detections": detections,
        "unknowns": unknowns,
        "residual_rms_db": round(20 * math.log10(max(res_rms, 1e-6)), 2),
    }
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=1)
    report(100, f"resultat : {args.output}")
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
