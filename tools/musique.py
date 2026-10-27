"""PartyBroc : génère les 2 boucles musicales originales (pas de droits d'auteur).

    python tools/musique.py        -> app/assets/music/salon.ogg et jeu.ogg

Synthé fait maison (numpy) : batterie, basse, accords, arpèges et mélodie.
Chaque boucle est rendue deux fois puis on garde la 2e : les échos et la
réverbération de la fin retombent sur le début, la boucle est sans couture.
Pour utiliser d'autres musiques (Pixabay…), remplacer simplement les .ogg.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'music')


def hz(n):  # n = numéro MIDI
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, a, d, s, r, length):
    """Enveloppe ADSR (secondes) sur n échantillons ; la note dure `length` s."""
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), 1.0)
    e = np.where((t >= a) & (t < a + d), 1 - (1 - s) * (t - a) / max(d, 1e-4), e)
    e = np.where((t >= a + d) & (t < length), s, e)
    e = np.where(t >= length, s * np.exp(-(t - length) / max(r, 1e-4)), e)
    return e


def add(buf, start, sig):
    i = int(start * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


# ---------------------------------------------------------------- instruments
def kick(vol=1.0):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 50 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return vol * np.sin(ph) * np.exp(-t * 9)


def snare(vol=1.0):
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    noise = noise - np.concatenate([[0], noise[:-1]]) * 0.6  # un peu plus brillant
    return vol * (0.45 * noise * np.exp(-t * 22) + 0.45 * np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25))


def clap(vol=1.0):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    burst = np.zeros(n)
    for k in range(3):
        o = int(k * 0.011 * SR)
        burst[o:] += np.exp(-np.arange(n - o) / SR * 60)
    return vol * noise * (0.5 * burst + np.exp(-t * 14)) * 0.3


def hat(vol=1.0, open_=False):
    n = int((0.22 if open_ else 0.05) * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    hp = noise - np.concatenate([[0], noise[:-1]])  # passe-haut grossier
    return vol * hp * np.exp(-t * (14 if open_ else 70)) * 0.13


def shaker(vol=1.0):
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    hp = noise - np.concatenate([[0], noise[:-1]])
    return vol * hp * np.sin(np.pi * t / t[-1]) * 0.07


def bass(note, length, vol=1.0, pluck=True):
    n = int((length + 0.15) * SR)
    t = np.arange(n) / SR
    f = hz(note)
    sig = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) + 0.15 * np.sin(2 * np.pi * 3 * f * t)
    e = env(n, 0.005, 0.12 if pluck else 0.05, 0.55 if pluck else 0.85, 0.06, length)
    return vol * sig * e * 0.5


def epiano(notes, length, vol=1.0):
    """Piano électrique doux (accord)."""
    n = int((length + 0.6) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k, note in enumerate(notes):
        f = hz(note)
        tone = np.sin(2 * np.pi * f * t + 0.8 * np.sin(2 * np.pi * f * t) * np.exp(-t * 6))
        out += tone * (1.0 - 0.08 * k)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.5 * t)
    return vol * out / len(notes) * env(n, 0.01, 0.4, 0.5, 0.35, length) * trem * 0.45


def pad(notes, length, vol=1.0):
    n = int((length + 0.8) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for note in notes:
        for det in (-0.12, 0.0, 0.12):  # léger chorus
            f = hz(note + det)
            out += 2 * (t * f - np.floor(t * f + 0.5))  # dent de scie
    out /= len(notes) * 3
    # adoucir (filtre passe-bas simple)
    for _ in range(3):
        out = np.convolve(out, np.ones(9) / 9, mode='same')
    return vol * out * env(n, 0.25, 0.3, 0.8, 0.6, length) * 0.35


def pluck(note, length, vol=1.0, bright=1.0):
    n = int((length + 0.25) * SR)
    t = np.arange(n) / SR
    f = hz(note)
    sq = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + np.sin(2 * np.pi * f * t) * 0.5
    filt = np.exp(-t * (18 / bright))
    sig = sq * filt + np.sin(2 * np.pi * f * t) * (1 - filt) * 0.4
    return vol * sig * env(n, 0.003, 0.12, 0.25, 0.08, length) * 0.3


def bell(note, length, vol=1.0):
    n = int((length + 0.8) * SR)
    t = np.arange(n) / SR
    f = hz(note)
    sig = np.sin(2 * np.pi * f * t + 1.5 * np.sin(2 * np.pi * 3.5 * f * t) * np.exp(-t * 5))
    return vol * sig * np.exp(-t * 3.2) * 0.32


# ---------------------------------------------------------------- effets
def delay(sig, sec, fb, mix):
    d = int(sec * SR)
    out = sig.copy()
    for k in range(1, 6):
        g = mix * fb ** (k - 1)
        if g < 0.02:
            break
        out[d * k:] += sig[: len(sig) - d * k] * g
    return out


def reverb(sig, mix=0.18):
    out = sig.copy()
    for ms, g in ((29, .5), (37, .45), (43, .4), (53, .35), (67, .3), (79, .25), (97, .2)):
        d = int(ms / 1000 * SR)
        tmp = np.zeros_like(sig)
        tmp[d:] = sig[:-d]
        for _ in range(3):  # quelques rebonds
            tmp[d:] += tmp[:-d] * 0.35
        out += tmp * g * mix
    return out


def master(stereo):
    peak = np.max(np.abs(stereo)) or 1
    x = stereo / peak * 1.4
    x = np.tanh(x) / np.tanh(1.4)  # compression douce
    return x * 0.89


def save(name, stereo):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        tmp = f.name
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dst = os.path.join(OUT, name)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '4', dst], check=True)
    os.remove(tmp)
    print(f'{dst}  {len(stereo) / SR:.1f} s  {os.path.getsize(dst) // 1024} Ko')


def render(bars, bpm, build):
    """build(drums, bassL, keys, lead, beat) remplit les pistes pour `bars` mesures (4 temps)."""
    beat = 60 / bpm
    loop = bars * 4 * beat
    n = int(loop * SR)
    tracks = {k: np.zeros(n * 2 + SR) for k in ('drums', 'bass', 'keys', 'lead')}
    for rep in range(2):
        build(tracks, beat, rep * loop)
    # effets, puis on garde la 2e boucle
    keys = reverb(tracks['keys'], 0.25)
    lead = reverb(delay(tracks['lead'], beat * 0.75, 0.4, 0.35), 0.3)
    drums, bas = tracks['drums'], tracks['bass']
    L = drums + bas + keys * 1.4 + lead * 1.1
    R = drums + bas + np.roll(keys, int(0.012 * SR)) * 1.4 + np.roll(lead, int(0.018 * SR)) * 1.1
    st = np.stack([L, R], axis=1)[n:2 * n]
    return master(st)


# ---------------------------------------------------------------- 1. salon (détendu, groovy)
def salon(tr, b, t0):
    # Fmaj7 – Em7 – Dm7 – Cmaj7, deux fois, 16 mesures
    chords = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]
    roots = [41, 40, 38, 36]
    melody = [  # (temps depuis début de la mesure, note, durée en temps) sur 4 mesures, en pentatonique
        [(0, 76, 1), (1.5, 74, .5), (2, 72, 1), (3, 69, 1)],
        [(0.5, 71, .5), (1, 72, 1), (2.5, 74, 1.5)],
        [(0, 72, .5), (0.5, 69, .5), (1, 67, 1), (2, 69, 2)],
        [(0, 64, 1), (1, 67, 1), (2, 72, 2)],
    ]
    for bar in range(16):
        s = t0 + bar * 4 * b
        c = bar % 4
        # batterie
        for k in range(4):
            if k in (0, 2):
                add(tr['drums'], s + k * b, kick(0.8))
            if k in (1, 3):
                add(tr['drums'], s + k * b, snare(0.32))
            for h in (0, .5):
                add(tr['drums'], s + (k + h) * b, hat(0.55 if h else 0.35))
            add(tr['drums'], s + (k + .75) * b, shaker(1))
        if bar % 4 == 3:
            add(tr['drums'], s + 3.5 * b, kick(0.5))
        # basse funky
        r = roots[c]
        for tb, off, ln in ((0, 0, .75), (1.5, 0, .4), (2, 7, .5), (2.75, 12, .25), (3, 0, .75)):
            add(tr['bass'], s + tb * b, bass(r + off, ln * b, 0.9))
        # accords (en contretemps, façon funk)
        for tb in (0.5, 1.75, 2.5, 3.5):
            add(tr['keys'], s + tb * b, epiano(chords[c], 0.35 * b, 0.9))
        # mélodie sur les 8 dernières mesures
        if bar >= 8:
            for tb, note, ln in melody[c]:
                add(tr['lead'], s + tb * b, bell(note, ln * b, 0.75))


# ---------------------------------------------------------------- 2. jeu (énergique)
def jeu(tr, b, t0):
    # Am – F – C – G, 16 mesures
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
    roots = [45, 41, 36, 43]
    for bar in range(16):
        s = t0 + bar * 4 * b
        c = bar % 4
        for k in range(4):
            add(tr['drums'], s + k * b, kick(0.95))
            if k in (1, 3):
                add(tr['drums'], s + k * b, clap(0.6))
            add(tr['drums'], s + (k + .5) * b, hat(0.7, open_=True))
            for h in (.25, .75):
                add(tr['drums'], s + (k + h) * b, hat(0.3))
        # basse en croches
        for e in range(8):
            add(tr['bass'], s + e * .5 * b, bass(roots[c] + (12 if e % 2 else 0), .42 * b, 0.85))
        # nappe
        add(tr['keys'], s, pad([n + 12 for n in chords[c]], 4 * b, 0.8))
        # arpège en doubles croches (à partir de la mesure 5)
        if bar >= 4:
            arp = chords[c] + [chords[c][0] + 12]
            for e in range(16):
                note = arp[(e * 2 + (e // 4)) % len(arp)] + 12
                add(tr['lead'], s + e * .25 * b, pluck(note, .2 * b, 0.55, bright=1 + (bar % 8) / 4))


if __name__ == '__main__':
    save('salon.ogg', render(16, 108, salon))
    save('jeu.ogg', render(16, 126, jeu))
