"""Generates Ball Wars' 8-bit sounds into assets/sounds/ (original, made here,
so there is nothing to license). NES-style voices: two pulse (square) waves,
a stepped triangle for bass and a noise channel for drums.

    python tool/sounds/make_sounds.py

Needs numpy. Output: 22.05 kHz mono 16-bit WAV (WAV loops without gaps,
unlike MP3). The background tracks are composed in music.py.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'sounds')


def freq(note):
    """'A4', 'C#5', 'Bb3' -> Hz."""
    names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    n = names[note[0]]
    rest = note[1:]
    if rest[0] == '#':
        n += 1
        rest = rest[1:]
    elif rest[0] == 'b':
        n -= 1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


def phase_of(f, n):
    f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
    return np.cumsum(f / SR) % 1.0


def pulse(f, n, duty=0.5):
    return np.where(phase_of(f, n) < duty, 1.0, -1.0)


def triangle(f, n):
    x = 4 * np.abs(phase_of(f, n) - 0.5) - 1
    return np.round((x + 1) * 7.5) / 7.5 - 1  # 16 steps, like the NES


def noise(n, rate=8000, seed=1):
    rng = np.random.default_rng(seed)
    hold = max(1, SR // rate)
    return np.repeat(rng.choice([-1.0, 1.0], n // hold + 1), hold)[:n]


def env(n, attack=0.002, release=0.03, sustain=1.0, decay=None):
    """Attack, optional exponential decay, release at the end (no tails)."""
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / attack) if attack > 0 else np.ones(n)
    if decay:
        e = e * (sustain + (1 - sustain) * np.exp(-t / decay))
    r = int(release * SR)
    if 0 < r < n:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def save(name, x, peak=0.85):
    x = x / max(1e-9, np.max(np.abs(x))) * peak
    data = (x * 32767).astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f'{name}: {len(x) / SR:.2f}s')


def samples(seconds):
    return int(seconds * SR)


# --- Sound effects -----------------------------------------------------------

def click():
    n = samples(0.035)
    return pulse(1568, n, 0.25) * env(n, release=0.012, decay=0.012, sustain=0.0)


def bounce():
    n = samples(0.07)
    f = np.geomspace(520, 260, n)
    return pulse(f, n, 0.5) * env(n, release=0.02, decay=0.03, sustain=0.2)


def collide():
    n = samples(0.08)
    tone = pulse(np.geomspace(880, 620, n), n, 0.25) * env(n, release=0.02, decay=0.035, sustain=0.1)
    hit = noise(n, rate=11000, seed=3) * env(n, release=0.01, decay=0.012, sustain=0.0)
    return tone * 0.7 + hit * 0.5


def out():
    """Knocked out: a stepped falling slide."""
    n = samples(0.55)
    steps = np.repeat(np.geomspace(784, 98, 14), n // 14 + 1)[:n]
    return pulse(steps, n, 0.5) * env(n, release=0.08)


def win():
    s = 0.075  # one sixteenth
    lead = [('C5', 1), ('E5', 1), ('G5', 1), ('C6', 1), ('E5', 1), ('G5', 1), ('C6', 2), ('G5', 2), ('C6', 10)]
    harm = [('G4', 1), ('C5', 1), ('E5', 1), ('G5', 1), ('C5', 1), ('E5', 1), ('G5', 2), ('E5', 2), ('G5', 10)]
    bass = [('C3', 4), ('G2', 4), ('C3', 12)]
    total = samples(s * 20 + 0.1)
    mix = np.zeros(total)

    def voice(notes, gen, gain, vibrato=False):
        pos = 0
        for note, length in notes:
            n = samples(s * length)
            f = np.full(n, freq(note))
            if vibrato and length >= 8:
                t = np.arange(n) / SR
                f = f * (1 + 0.012 * np.sin(2 * np.pi * 6 * t) * np.minimum(1, t / 0.15))
            mix[pos:pos + n] += gen(f, n) * env(n, release=min(0.25, n / SR * 0.5)) * gain
            pos += n

    voice(lead, lambda f, n: pulse(f, n, 0.5), 0.35, vibrato=True)
    voice(harm, lambda f, n: pulse(f, n, 0.25), 0.2, vibrato=True)
    voice(bass, triangle, 0.45)
    for i in range(4):  # snare roll into the last note
        n = samples(0.06)
        p = samples(s * (4 + i))
        mix[p:p + n] += noise(n, seed=10 + i) * env(n, release=0.02, decay=0.02, sustain=0) * 0.25
    return mix


def slowed(x, factor=2.0):
    """Slow-motion version: stretched (so lower and longer) and muffled."""
    n = int(len(x) * factor)
    y = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)
    k = 6
    return np.convolve(y, np.ones(k) / k, mode='same')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    save('click.wav', click(), 0.5)
    save('bounce.wav', bounce(), 0.6)
    save('collide.wav', collide(), 0.7)
    save('bounce_slow.wav', slowed(bounce()), 0.4)
    save('collide_slow.wav', slowed(collide()), 0.45)
    save('out.wav', out(), 0.6)
    save('win.wav', win(), 0.8)
    from music import TRACKS  # noqa: E402 (music.py reuses the helpers above)

    for track_id, track in TRACKS:
        save(f'bgm_{track_id}.wav', track(), 0.75)
