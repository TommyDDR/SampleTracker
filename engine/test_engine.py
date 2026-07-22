"""Test phase 4 : moteur d'analyse sur mix synthétique à vérité terrain connue.

Lancement : python engine/test_engine.py   (exit 0 = PASS)

Construit 3 samples WAV (bruit décroissant, sinus enveloppé, chirp), un mix
avec gains/positions connus dont deux samples superposés, plus un son INCONNU
(carré 300 Hz absent de la bibliothèque). Vérifie : toutes les occurrences
trouvées (position < 10 ms, gain < 1 dB d'erreur), aucune fausse détection,
bloc INCONNU localisé.
"""

import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))

failures = 0


def check(cond: bool, label: str):
    global failures
    print(("  ok  " if cond else "  KO  ") + label)
    if not cond:
        failures += 1


def write_wav(path: str, data: np.ndarray):
    pcm = np.clip(data * 32767, -32768, 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main() -> int:
    rng = np.random.default_rng(42)
    tmp = tempfile.mkdtemp(prefix="sampletracker_engine_")
    samples_dir = os.path.join(tmp, "samples")
    os.makedirs(samples_dir)

    # --- Bibliothèque de samples ------------------------------------------
    t = np.arange(int(0.4 * SR)) / SR
    impact = (rng.standard_normal(len(t)) * np.exp(-t * 12)).astype(np.float32) * 0.7

    t = np.arange(int(0.8 * SR)) / SR
    env = np.minimum(1, np.minimum(t / 0.05, (0.8 - t) / 0.05))
    tone = (np.sin(2 * np.pi * 440 * t) * env).astype(np.float32) * 0.8

    t = np.arange(int(0.6 * SR)) / SR
    sweep = (np.sin(2 * np.pi * (200 * t + (1800 / (2 * 0.6)) * t * t)) * 0.6).astype(np.float32)

    write_wav(os.path.join(samples_dir, "impact.wav"), impact)
    write_wav(os.path.join(samples_dir, "tone.wav"), tone)
    write_wav(os.path.join(samples_dir, "sweep.wav"), sweep)

    # --- Mix : vérité terrain ---------------------------------------------
    truth = [
        ("impact.wav", impact, 1.000, 0.80),
        ("tone.wav", tone, 2.500, 0.50),
        ("impact.wav", impact, 2.700, 0.60),  # superposé au tone
        ("sweep.wav", sweep, 4.200, 0.90),
    ]
    mix = np.zeros(int(8 * SR), dtype=np.float32)
    for _name, data, start, gain in truth:
        i = int(start * SR)
        mix[i:i + len(data)] += gain * data

    # Son inconnu : carré 300 Hz, absent de la bibliothèque
    t = np.arange(int(0.5 * SR)) / SR
    unknown = np.sign(np.sin(2 * np.pi * 300 * t)).astype(np.float32) * 0.4
    i = int(6 * SR)
    mix[i:i + len(unknown)] += unknown

    source_path = os.path.join(tmp, "mix.wav")
    write_wav(source_path, mix)

    # --- Analyse -----------------------------------------------------------
    out_path = os.path.join(tmp, "result.json")
    proc = subprocess.run(
        [sys.executable, os.path.join(HERE, "analyze.py"),
         "--source", source_path, "--samples", samples_dir,
         "--output", out_path, "--threshold", "0.6"],
        capture_output=True, text=True)
    check(proc.returncode == 0, f"analyze.py exit 0 (stderr: {proc.stderr.strip()[:200]})")
    if proc.returncode != 0:
        print(proc.stdout[-2000:])
        return 1
    with open(out_path, encoding="utf-8") as f:
        result = json.load(f)

    detections = result["detections"]
    check(len(detections) == len(truth), f"{len(truth)} détections (obtenu {len(detections)})")

    for name, _data, start, gain in truth:
        match = [d for d in detections
                 if d["sample"] == name and abs(d["start"] - start) < 0.010]
        check(len(match) == 1, f"{name} @ {start:.3f}s trouvé une fois (x{len(match)})")
        if match:
            d = match[0]
            err_db = abs(20 * math.log10(d["gain"] / gain))
            check(err_db < 1.0, f"{name} @ {start:.3f}s gain {gain:.2f} vs {d['gain']:.3f} "
                                f"({err_db:.2f} dB)")
            check(d["confidence"] > 0.8, f"{name} @ {start:.3f}s confiance {d['confidence']:.3f}")

    unknowns = result["unknowns"]
    hit = [u for u in unknowns if u["start"] < 6.5 and u["start"] + u["duration"] > 6.0]
    check(len(hit) >= 1, f"bloc INCONNU sur [6.0, 6.5] (obtenu {json.dumps(unknowns)})")
    check(all(u["start"] >= 5.5 for u in unknowns),
          "pas de faux INCONNU avant le carré (résidu propre)")

    # --- Robustesse MP3 : mix ré-encodé lossy (cas réel) -------------------
    ffmpeg = None
    for cand in (os.path.join(HERE, "..", "bin", "ffmpeg.exe"), "ffmpeg"):
        if cand == "ffmpeg" or os.path.isfile(cand):
            ffmpeg = cand
            break
    mp3_path = os.path.join(tmp, "mix.mp3")
    enc = subprocess.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                          "-i", source_path, "-b:a", "192k", mp3_path],
                         capture_output=True, text=True)
    if enc.returncode == 0:
        out2 = os.path.join(tmp, "result_mp3.json")
        proc2 = subprocess.run(
            [sys.executable, os.path.join(HERE, "analyze.py"),
             "--source", mp3_path, "--samples", samples_dir,
             "--output", out2, "--threshold", "0.5"],
            capture_output=True, text=True)
        check(proc2.returncode == 0, "analyze.py sur MP3 exit 0")
        with open(out2, encoding="utf-8") as f:
            result2 = json.load(f)
        det2 = result2["detections"]
        for name, _data, start, gain in truth:
            match = [d for d in det2
                     if d["sample"] == name and abs(d["start"] - start) < 0.010]
            ok = len(match) >= 1
            check(ok, f"[MP3] {name} @ {start:.3f}s retrouvé")
            if ok:
                err_db = abs(20 * math.log10(match[0]["gain"] / gain))
                check(err_db < 2.0, f"[MP3] {name} @ {start:.3f}s gain à {err_db:.2f} dB")
    else:
        print("  --  ffmpeg indisponible : test MP3 sauté")

    shutil.rmtree(tmp, ignore_errors=True)
    if failures:
        print(f"FAIL : {failures} échec(s)")
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
