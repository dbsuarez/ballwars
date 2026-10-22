"""Ball Wars' background music: five 16-bar chiptune loops (see make_sounds.py,
which writes them as assets/sounds/bgm_<id>.wav). The admin picks the track
for everyone (app_settings.music; ids must match MusicTrack in the app).

A song is a tempo, one chord per bar, a lead melody per bar ((note, length in
sixteenths); None is a rest) and arpeggio / bass / drum styles.
"""
import numpy as np

from make_sounds import env, noise, pulse, samples, triangle

NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
QUALITY = {'': [0, 4, 7], 'm': [0, 3, 7], '7': [0, 4, 7, 10], 'm7': [0, 3, 7, 10], 'maj7': [0, 4, 7, 11]}


def midi(note):
    n = NOTE[note[0]]
    rest = note[1:]
    if rest[0] in '#b':
        n += 1 if rest[0] == '#' else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + n


def mfreq(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def chord(name):
    """'Bbmaj7' -> (root midi in octave 3, intervals)."""
    root = name[0] + (name[1] if len(name) > 1 and name[1] in '#b' else '')
    return midi(root + '3'), QUALITY[name[len(root):]]


def song(tempo, chords, melody, *, lead_duty=0.25, lead_gain=0.22, arp='up', arp_gain=0.08,
         bass='octave', drums='rock'):
    s = 60 / tempo / 4  # one sixteenth
    bar = 16
    total = samples(s * bar * len(chords))
    mix = np.zeros(total)

    def at(sixteenth):
        return samples(s * sixteenth)

    def add(start, x, gain):
        end = min(total, start + len(x))
        mix[start:end] += x[:end - start] * gain

    def note(start, length, m, gen, gain, release=0.02, decay=None, sustain=1.0, trim=40):
        n = at(length) - trim
        add(at(start), gen(mfreq(m), n) * env(n, release=release, decay=decay, sustain=sustain), gain)

    def lead(f, n):
        return pulse(f, n, lead_duty)

    def thin(f, n):
        return pulse(f, n, 0.125)

    def quarter(f, n):
        return pulse(f, n, 0.25)

    for b, name in enumerate(chords):
        base = b * bar
        root, steps = chord(name)
        next_root, _ = chord(chords[(b + 1) % len(chords)])
        notes = melody[b]
        assert sum(length for _, length in notes) == bar, f'bar {b + 1} ({name}) is not 16 sixteenths'

        pos = base
        for pitch, length in notes:
            if pitch:
                note(pos, length, midi(pitch), lead, lead_gain, release=0.03, decay=0.25, sustain=0.6)
            pos += length

        tones = [root + 12 + i for i in steps]  # octave 4
        if arp == 'up':
            for i in range(bar):
                m = tones[i % len(tones)] + (12 if i % (2 * len(tones)) >= len(tones) else 0)
                note(base + i, 1, m, thin, arp_gain, release=0.01, decay=0.05, sustain=0.3, trim=30)
        elif arp == 'updown':
            seq = tones + [t + 12 for t in tones]
            seq = seq + seq[-2:0:-1]
            for i in range(bar):
                note(base + i, 1, seq[i % len(seq)], thin, arp_gain, release=0.01, decay=0.05, sustain=0.3, trim=30)
        elif arp == 'broken':
            for i in range(0, bar, 2):
                note(base + i, 2, tones[(i // 2) % len(tones)], quarter, arp_gain, release=0.04, decay=0.12,
                     sustain=0.2)

        low = root - 12  # octave 2
        if bass == 'octave':
            for i in range(0, bar, 2):
                note(base + i, 2, low + (0 if i % 4 == 0 else 12), triangle, 0.32, trim=60)
        elif bass == 'drive':
            for i in range(0, bar, 2):
                note(base + i, 2, low + (7 if i == 14 else 0), triangle, 0.34, trim=80)
        elif bass == 'walk':
            for i, step in enumerate([0, steps[1], 7, 9 if steps[1] == 4 else 10]):
                note(base + i * 4, 4, low + step, triangle, 0.34, trim=120)
        elif bass == 'chroma':
            for i in range(0, bar, 2):
                # The last eighth leans a semitone into the next chord.
                m = low if i < 14 else next_root - 12 + (1 if next_root > root else -1)
                note(base + i, 2, m, triangle, 0.34, trim=60)

        kicks, snares, hats = {
            'rock': ((0, 8), (4, 12), (2, 6, 10, 14)),
            'disco': ((0, 4, 8, 12), (4, 12), (2, 6, 10, 14)),
            'boss': ((0, 3, 8, 11), (4, 12), tuple(range(0, 16, 2))),
            'chill': ((0, 10), (8,), (4, 12)),
        }[drums]
        for i in kicks:
            n = samples(0.09)
            add(at(base + i), triangle(np.geomspace(150, 45, n), n) * env(n, release=0.02, decay=0.04, sustain=0), 0.4)
        for i in snares:
            n = samples(0.12)
            add(at(base + i), noise(n, rate=9000, seed=b * 2 + i) * env(n, release=0.03, decay=0.04, sustain=0), 0.16)
        for i in hats:
            n = samples(0.03)
            add(at(base + i), noise(n, rate=20000, seed=b + i) * env(n, release=0.01, decay=0.01, sustain=0), 0.06)
    return mix


def arena():
    """The original theme: A minor, 140 bpm."""
    return song(140, ['Am', 'F', 'C', 'G', 'Am', 'F', 'C', 'G', 'F', 'G', 'Em', 'Am', 'F', 'G', 'E', 'E'], [
        [('E5', 4), ('D5', 2), ('C5', 2), ('B4', 4), ('C5', 4)],
        [('A4', 6), ('C5', 2), ('F5', 4), ('E5', 4)],
        [('G4', 4), ('C5', 4), ('E5', 4), ('G5', 4)],
        [('D5', 6), ('B4', 2), ('G4', 4), (None, 4)],
        [('E5', 4), ('D5', 2), ('C5', 2), ('B4', 4), ('C5', 4)],
        [('A4', 6), ('C5', 2), ('F5', 4), ('A5', 4)],
        [('G5', 4), ('E5', 4), ('C5', 4), ('E5', 4)],
        [('D5', 8), ('B4', 4), ('D5', 4)],
        [('A5', 2), ('G5', 2), ('F5', 4), ('C5', 4), ('F5', 4)],
        [('B5', 2), ('A5', 2), ('G5', 4), ('D5', 4), ('G5', 4)],
        [('G5', 4), ('E5', 4), ('B4', 4), ('E5', 4)],
        [('A5', 8), ('E5', 4), ('C5', 4)],
        [('A5', 2), ('G5', 2), ('F5', 4), ('C5', 4), ('A5', 4)],
        [('B5', 4), ('D6', 4), ('B5', 4), ('G5', 4)],
        [('G#5', 8), ('E5', 4), ('B4', 4)],
        [('G#4', 4), ('B4', 4), ('E5', 4), (None, 4)],
    ])


def turbo():
    """Fast and driving: E minor, 168 bpm, four-on-the-floor."""
    return song(168, ['Em', 'C', 'G', 'D', 'Em', 'C', 'D', 'B7', 'C', 'D', 'Em', 'Em', 'C', 'D', 'B7', 'B7'], [
        [('E5', 2), ('G5', 2), ('B5', 2), ('G5', 2), ('E5', 2), ('G5', 2), ('B5', 4)],
        [('C6', 4), ('B5', 2), ('A5', 2), ('G5', 4), ('E5', 4)],
        [('D5', 2), ('G5', 2), ('B5', 2), ('D6', 2), ('B5', 4), ('G5', 4)],
        [('F#5', 6), ('E5', 2), ('D5', 4), ('F#5', 4)],
        [('E5', 2), ('G5', 2), ('B5', 2), ('G5', 2), ('E5', 2), ('G5', 2), ('B5', 4)],
        [('C6', 4), ('E6', 4), ('D6', 4), ('C6', 4)],
        [('D6', 4), ('C6', 2), ('B5', 2), ('A5', 4), ('F#5', 4)],
        [('D#5', 8), ('F#5', 4), ('A5', 4)],
        [('G5', 2), ('G5', 2), ('E5', 4), ('G5', 4), ('C6', 4)],
        [('A5', 2), ('A5', 2), ('F#5', 4), ('A5', 4), ('D6', 4)],
        [('B5', 4), ('G5', 4), ('E5', 4), ('G5', 4)],
        [('B5', 12), (None, 4)],
        [('E6', 2), ('D6', 2), ('C6', 4), ('G5', 4), ('E5', 4)],
        [('F#6', 2), ('E6', 2), ('D6', 4), ('A5', 4), ('F#5', 4)],
        [('D#6', 8), ('B5', 4), ('F#5', 4)],
        [('A5', 4), ('F#5', 4), ('D#5', 4), ('B4', 4)],
    ], lead_duty=0.5, lead_gain=0.18, bass='drive', drums='disco', arp_gain=0.06)


def sunny():
    """Bouncy and bright: C major, 132 bpm."""
    return song(132, ['C', 'Am', 'F', 'G', 'C', 'Am', 'Dm', 'G', 'F', 'G', 'Em', 'Am', 'F', 'G', 'C', 'C'], [
        [('C5', 2), ('E5', 2), ('G5', 4), ('E5', 2), ('G5', 2), ('C6', 4)],
        [('A5', 4), ('G5', 2), ('E5', 2), ('C5', 4), ('E5', 4)],
        [('F5', 2), ('A5', 2), ('C6', 4), ('A5', 4), ('F5', 4)],
        [('G5', 6), ('F5', 2), ('E5', 4), ('D5', 4)],
        [('C5', 2), ('E5', 2), ('G5', 4), ('E5', 2), ('G5', 2), ('C6', 4)],
        [('A5', 4), ('C6', 4), ('E6', 4), ('C6', 4)],
        [('D6', 4), ('C6', 2), ('A5', 2), ('F5', 4), ('A5', 4)],
        [('G5', 8), ('B5', 4), ('D6', 4)],
        [('C6', 2), ('A5', 2), ('F5', 4), ('A5', 2), ('C6', 2), ('F6', 4)],
        [('D6', 2), ('B5', 2), ('G5', 4), ('B5', 2), ('D6', 2), ('G6', 4)],
        [('E6', 4), ('D6', 2), ('B5', 2), ('G5', 4), ('B5', 4)],
        [('C6', 8), ('A5', 4), ('E5', 4)],
        [('A5', 2), ('C6', 2), ('F6', 4), ('E6', 2), ('D6', 2), ('C6', 4)],
        [('B5', 2), ('D6', 2), ('G6', 4), ('F6', 2), ('E6', 2), ('D6', 4)],
        [('E6', 8), ('G6', 4), ('E6', 4)],
        [('C6', 8), ('G5', 4), (None, 4)],
    ], lead_duty=0.125, lead_gain=0.24, arp='updown', bass='walk')


def boss():
    """Tense: D harmonic minor, 150 bpm, chromatic bass."""
    return song(150, ['Dm', 'Dm', 'Bb', 'A', 'Dm', 'Dm', 'Gm', 'A7', 'Bb', 'A', 'Dm', 'Dm', 'Gm', 'A7', 'Dm', 'A7'], [
        [('D5', 4), ('F5', 2), ('A5', 2), ('D6', 4), ('A5', 4)],
        [('C#6', 4), ('D6', 2), ('E6', 2), ('F6', 4), ('E6', 4)],
        [('D6', 4), ('Bb5', 4), ('F5', 4), ('Bb5', 4)],
        [('C#6', 8), ('E6', 4), ('A5', 4)],
        [('D5', 4), ('F5', 2), ('A5', 2), ('D6', 4), ('A5', 4)],
        [('F6', 4), ('E6', 2), ('D6', 2), ('C#6', 4), ('D6', 4)],
        [('Bb5', 4), ('A5', 2), ('G5', 2), ('D6', 4), ('Bb5', 4)],
        [('A5', 8), ('C#6', 4), ('E6', 4)],
        [('F6', 2), ('F6', 2), ('D6', 4), ('Bb5', 4), ('F5', 4)],
        [('E6', 2), ('E6', 2), ('C#6', 4), ('A5', 4), ('E5', 4)],
        [('D6', 4), ('A5', 4), ('F5', 4), ('A5', 4)],
        [('D6', 12), (None, 4)],
        [('G6', 4), ('F6', 2), ('E6', 2), ('D6', 4), ('Bb5', 4)],
        [('C#6', 4), ('E6', 4), ('G6', 4), ('E6', 4)],
        [('F6', 8), ('E6', 4), ('D6', 4)],
        [('C#6', 4), ('A5', 4), ('E5', 4), ('C#5', 4)],
    ], lead_duty=0.5, lead_gain=0.18, bass='chroma', drums='boss')


def chill():
    """Laid back: F major, 96 bpm, half-time drums."""
    return song(96, ['Fmaj7', 'Dm', 'Bbmaj7', 'C', 'Fmaj7', 'Dm', 'Gm', 'C',
                     'Bbmaj7', 'C', 'Am', 'Dm', 'Gm', 'C', 'Fmaj7', 'F'], [
        [('A5', 6), ('G5', 2), ('F5', 4), ('C5', 4)],
        [('D5', 8), ('F5', 4), ('A5', 4)],
        [('D6', 6), ('C6', 2), ('A5', 4), ('F5', 4)],
        [('G5', 12), (None, 4)],
        [('A5', 6), ('G5', 2), ('F5', 4), ('A5', 4)],
        [('C6', 8), ('A5', 4), ('F5', 4)],
        [('Bb5', 6), ('A5', 2), ('G5', 4), ('D5', 4)],
        [('E5', 12), (None, 4)],
        [('F5', 4), ('A5', 4), ('D6', 8)],
        [('E5', 4), ('G5', 4), ('C6', 8)],
        [('E6', 6), ('D6', 2), ('C6', 4), ('A5', 4)],
        [('F5', 12), (None, 4)],
        [('D6', 6), ('C6', 2), ('Bb5', 4), ('G5', 4)],
        [('C6', 6), ('Bb5', 2), ('G5', 4), ('E5', 4)],
        [('F5', 8), ('A5', 4), ('C6', 4)],
        [('F5', 12), (None, 4)],
    ], lead_gain=0.2, arp='broken', arp_gain=0.1, bass='walk', drums='chill')


TRACKS = [('arena', arena), ('turbo', turbo), ('sunny', sunny), ('boss', boss), ('chill', chill)]
