#!/usr/bin/env python3
"""Generate first-party Jeffrey UI / Smash WAV packs (44.1 kHz 16-bit PCM)."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UI_DIR = ROOT / "assets" / "audio" / "ui"
SMASH_DIR = ROOT / "assets" / "audio" / "smash"
RATE = 44100


def _clamp(x: float) -> float:
    return max(-1.0, min(1.0, x))


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Remove DC offset and soft-normalize
    if samples:
        mean = sum(samples) / len(samples)
        samples = [s - mean for s in samples]
        peak = max(abs(s) for s in samples) or 1.0
        gain = 0.72 / peak
        samples = [_clamp(s * gain) for s in samples]
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(s * 32767)) for s in samples)
        wf.writeframes(frames)


def env(t: float, attack: float, release: float, dur: float) -> float:
    if t < attack:
        return t / max(attack, 1e-6)
    if t > dur - release:
        return max(0.0, (dur - t) / max(release, 1e-6))
    return 1.0


def tone(freq: float, dur: float, attack=0.005, release=0.04, amp=0.5, wave_fn=math.sin) -> list[float]:
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        out.append(amp * env(t, attack, release, dur) * wave_fn(2 * math.pi * freq * t))
    return out


def noise(dur: float, amp=0.2, attack=0.001, release=0.05) -> list[float]:
    # Deterministic cheap noise
    n = int(RATE * dur)
    out = []
    state = 1234567
    for i in range(n):
        state = (1103515245 * state + 12345) & 0x7FFFFFFF
        t = i / RATE
        out.append(amp * env(t, attack, release, dur) * ((state / 0x7FFFFFFF) * 2 - 1))
    return out


def mix(*parts: list[float]) -> list[float]:
    length = max((len(p) for p in parts), default=0)
    out = [0.0] * length
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def chirp(f0: float, f1: float, dur: float, amp=0.45) -> list[float]:
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * (t / dur)
        phase += 2 * math.pi * f / RATE
        out.append(amp * env(t, 0.004, 0.05, dur) * math.sin(phase))
    return out


def build_ui() -> None:
    specs = {
        "navigate.wav": mix(tone(660, 0.045, amp=0.28), tone(990, 0.035, amp=0.12)),
        "confirm.wav": mix(tone(392, 0.09, amp=0.35), tone(523, 0.12, amp=0.28), tone(784, 0.08, amp=0.15)),
        "back.wav": mix(tone(440, 0.08, amp=0.28), tone(330, 0.1, amp=0.22)),
        "error.wav": mix(tone(180, 0.14, amp=0.35), tone(160, 0.18, amp=0.2), noise(0.12, amp=0.08)),
        "modal_open.wav": mix(chirp(220, 520, 0.14, amp=0.32), tone(520, 0.1, amp=0.18)),
        "score_gain.wav": mix(tone(523, 0.1, amp=0.28), tone(659, 0.14, amp=0.3), tone(784, 0.18, amp=0.22)),
        "result.wav": mix(chirp(300, 700, 0.35, amp=0.3), tone(880, 0.25, amp=0.18), tone(1108, 0.2, amp=0.12)),
        "countdown_tick.wav": mix(tone(700, 0.06, amp=0.32), noise(0.04, amp=0.05)),
        "countdown_go.wav": mix(tone(523, 0.12, amp=0.3), tone(784, 0.2, amp=0.35), tone(1046, 0.18, amp=0.2)),
        "finish.wav": mix(chirp(350, 900, 0.4, amp=0.28), tone(659, 0.3, amp=0.2), tone(988, 0.25, amp=0.15)),
        "player_join.wav": mix(tone(440, 0.08, amp=0.25), tone(660, 0.12, amp=0.28)),
        "player_leave.wav": mix(tone(500, 0.08, amp=0.22), tone(300, 0.12, amp=0.2)),
    }
    for name, samples in specs.items():
        write_wav(UI_DIR / name, samples)
        print("ui", name, len(samples))


def build_smash() -> None:
    specs = {
        "hit_light.wav": mix(noise(0.05, amp=0.25), tone(220, 0.06, amp=0.2)),
        "hit_heavy.wav": mix(noise(0.09, amp=0.35), tone(140, 0.12, amp=0.35), tone(90, 0.1, amp=0.2)),
        "ko.wav": mix(chirp(200, 80, 0.35, amp=0.4), noise(0.2, amp=0.2), tone(110, 0.3, amp=0.25)),
        "respawn.wav": mix(chirp(180, 480, 0.22, amp=0.28), tone(640, 0.12, amp=0.15)),
        "match_start.wav": mix(tone(392, 0.1, amp=0.25), tone(523, 0.15, amp=0.3), tone(784, 0.18, amp=0.22)),
        "match_end.wav": mix(chirp(400, 700, 0.45, amp=0.28), tone(523, 0.3, amp=0.2)),
    }
    for name, samples in specs.items():
        write_wav(SMASH_DIR / name, samples)
        print("smash", name, len(samples))


if __name__ == "__main__":
    build_ui()
    build_smash()
    print("OK", UI_DIR, SMASH_DIR)
