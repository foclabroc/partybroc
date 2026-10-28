#!/usr/bin/env python3
"""Bruitages de PartyBroc (écran TV), fabriqués par synthèse : aucun droit d'auteur.

    python3 tools/bruitages.py      → app/assets/sfx/*.ogg

Chaque son peut être remplacé par un autre .ogg du même nom (Pixabay, Mixkit…).
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / 'app' / 'assets' / 'sfx'
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.005, release=0.1, sec=None):
    """Enveloppe montée rapide + descente exponentielle"""
    x = np.arange(n) / SR
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-x / release)


def lowpass(x, cutoff):
    """Filtre passe-bas simple (1 pôle)"""
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    # petit fondu de fin pour éviter le clic
    f = min(len(x), int(SR * 0.01))
    x[-f:] *= np.linspace(1, 0, f)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav') as tmp:
        with wave.open(tmp.name, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        OUT.mkdir(parents=True, exist_ok=True)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tmp.name, '-c:a', 'libvorbis', '-q:a', '4', str(OUT / f'{name}.ogg')], check=True)
    print('  ', name, f'{len(x) / SR:.2f} s')


def pop():
    """Un joueur arrive : « bloup » qui monte"""
    x = t(0.14)
    f = 380 + 900 * (x / x[-1]) ** 0.6
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(x), 0.003, 0.05)


def tick():
    """Dernières secondes : petit bloc de bois"""
    x = t(0.07)
    return (np.sin(2 * np.pi * 1900 * x) + 0.4 * np.sin(2 * np.pi * 3100 * x)) * env(len(x), 0.001, 0.012)


def whoosh():
    """Nouvelle question : souffle qui monte puis retombe"""
    x = t(0.45)
    n = rng.standard_normal(len(x))
    shape = np.sin(np.pi * x / x[-1]) ** 2
    return lowpass(n, 1800) * shape


def ding():
    """Révélation : cloche claire"""
    x = t(1.4)
    s = sum(a * np.sin(2 * np.pi * f * x) * np.exp(-x / d) for f, a, d in [(1046.5, 1, 0.6), (2093, 0.45, 0.35), (3140, 0.2, 0.2), (1568, 0.3, 0.45)])
    return s * np.clip(x / 0.003, 0, 1)


def buzz():
    """Éliminé / raté : buzzer grave"""
    x = t(0.5)
    sq = np.sign(np.sin(2 * np.pi * 130 * x)) + 0.5 * np.sign(np.sin(2 * np.pi * 137 * x))
    return lowpass(sq, 2200) * env(len(x), 0.005, 0.35)


def note(freq, sec, bright=2600):
    """Note de cuivre (dents de scie filtrées)"""
    x = t(sec)
    saw = sum(np.sin(2 * np.pi * freq * k * x) / k for k in range(1, 9))
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * x)
    saw = sum(np.sin(2 * np.pi * freq * k * x * vib) / k for k in range(1, 9))
    e = np.clip(x / 0.03, 0, 1) * np.clip((sec - x) / 0.08, 0, 1)
    return lowpass(saw, bright) * e


def fanfare():
    """Podium : petite fanfare (sol-do-mi-sol… do !)"""
    seq = [(392, 0.16), (523.25, 0.16), (659.25, 0.16), (783.99, 0.34), (659.25, 0.14), (783.99, 1.1)]
    out = []
    for f, d in seq:
        out.append(note(f, d) + 0.5 * note(f / 2, d))
    s = np.concatenate(out)
    # accord final un peu plus riche
    tail = int(SR * 1.1)
    s[-tail:] += 0.5 * note(523.25, 1.1)[:tail] + 0.4 * note(659.25, 1.1)[:tail]
    return s


def boom():
    """Feu d'artifice : sifflement, explosion, crépitements"""
    whistle_t = t(0.45)
    f = 900 + 1700 * (whistle_t / whistle_t[-1])
    whistle = 0.25 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip(whistle_t / 0.05, 0, 1)
    bang_t = t(1.6)
    bang = lowpass(rng.standard_normal(len(bang_t)), 500) * np.exp(-bang_t / 0.25) * 2.2
    bang += 0.8 * np.sin(2 * np.pi * 60 * bang_t) * np.exp(-bang_t / 0.18)
    crackle = np.zeros(len(bang_t))
    for _ in range(90):
        at = int(rng.uniform(0.2, 1.5) * SR)
        ln = int(SR * 0.006)
        if at + ln < len(crackle):
            crackle[at:at + ln] += rng.standard_normal(ln) * rng.uniform(0.2, 0.7) * np.exp(-(at / SR - 0.2) / 0.8)
    return np.concatenate([whistle, bang + crackle])


def applause():
    """Applaudissements : des centaines de petits claquements"""
    x = t(3.2)
    out = np.zeros(len(x))
    clap = lowpass(rng.standard_normal(int(SR * 0.012)), 3500) * np.exp(-np.arange(int(SR * 0.012)) / (SR * 0.003))
    for _ in range(900):
        at = int(rng.uniform(0, 3.0) * SR)
        if at + len(clap) < len(out):
            out[at:at + len(clap)] += clap * rng.uniform(0.3, 1)
    shape = np.clip(x / 0.25, 0, 1) * np.clip((3.2 - x) / 1.2, 0, 1)
    return out * shape


if __name__ == '__main__':
    print('Bruitages →', OUT)
    save('pop', pop(), 0.7)
    save('tick', tick(), 0.6)
    save('whoosh', whoosh(), 0.55)
    save('ding', ding(), 0.75)
    save('buzz', buzz(), 0.6)
    save('fanfare', fanfare(), 0.8)
    save('boom', boom(), 0.85)
    save('applause', applause(), 0.6)
