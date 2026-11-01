#!/usr/bin/env python3
"""Synthesises After Hours' eight music loops and encodes them to MP3.

Engine ported from Hunt Frenzy's tools/music.py (../hunt-frenzy, itself from BrewMagic's):
the note parser, plucked partials and bowed wavetables, wrap-around rendering, BS.1770
loudness, the lock file and the gapless MP3 checks. The band is new: every loop is built on
one original caper-jazz motif (MOTIF: a sneaking climb up a C minor chord with a chromatic
slip, answered by ANSWER), rearranged per wing in its painting's era:
    caper      title, hub and hideout: vibraphone over a walking pizzicato bass and brushes
    wing_01    Vermeer, 17th-century Delft: harpsichord with a continuo bass
    wing_02    Hokusai, Edo Japan: koto in a hirajoshi scale over a low drone, a frame drum
    wing_03    Seurat, 1880s Paris: music-hall accordion over an oom-pah piano
    wing_04    Van Gogh: swirling bowed strings over pizzicato bass
    wing_05    Bosch, around 1500: a shawm in the Dorian mode over a drone and a tabor
    wing_06    Leonardo, the Renaissance: lute in the Aeolian mode, picked chords
    results    the answer slowed on vibraphone, a warm close
The melodies are written here from scratch; none quotes any existing tune or game's music.
The era versions snap the motif's notes into their scale (remap), so it stays recognisable.

Each loop is rendered into a buffer exactly one loop long; note tails that run past the end
wrap around to the start, so the loop is seamless. lame records its encoder delay and padding
in the LAME/Xing tag and Godot's decoder (like ffmpeg) trims them, so the decoded file is
exactly one loop and Godot's plain loop is seamless. Never pass lame -t: it drops that tag.
After encoding, each file is decoded (gapless) with ffmpeg to check it is exactly one loop
long, and the loop is switched on in its .import file.

The rendered PCM of every loop is deterministic (stdlib only, fixed seeds); its sha256 and
length are recorded in tools/music.lock.json with the sha256 and size of the MP3 made from
it, which --check compares against a fresh render and the committed files (no lame or
ffmpeg needed, so validate.sh runs it).

Usage (from repo root):
    python3 tools/music.py           render, encode afterhours/audio/music/<track>.mp3, write the lock
    python3 tools/music.py --check   render in memory and verify the lock, the MP3s and their
                                     .import loop flags; prints "music: OK"
Generating needs lame and ffmpeg on PATH (Homebrew: brew install lame ffmpeg). The MP3s are
constant bitrate (80 kbps mono) without ID3 tags.
"""
import hashlib
import json
import math
import operator
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

from sfx import k_weighted

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "afterhours"
OUT_DIR = PROJECT / "audio" / "music"
LOCK = ROOT / "tools" / "music.lock.json"
RATE = 32000
# Music sits under the sound effects: every loop is set to the same integrated loudness,
# LOUDNESS LUFS (BS.1770 gated, loudness()), under the effects' events (tools/sfx.py
# LOUDNESS_BANDS, about -24..-14), so no loop is louder than another. No sample may pass PEAK.
LOUDNESS = -26.0
PEAK = 0.6
# BS.1770's gating: LOUDNESS_BLOCK-second blocks every LOUDNESS_HOP seconds, an absolute gate
# at -70 LUFS and a relative gate 10 LU under the absolutely gated mean.
LOUDNESS_BLOCK = 0.4
LOUDNESS_HOP = 0.1
NOTE_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
FLAT_NAMES = ("C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B")
# The loops together must stay under this (the web build stays small).
MAX_TOTAL_BYTES = 4 * 1024 * 1024
# Steps (8th notes) per bar: every track is in 4/4.
BAR_STEPS = 8


class MusicError(Exception):
    pass


def midi(note):
    """'C5', 'F#4', 'Bb3' -> MIDI note number."""
    name, octave = note[:-1], int(note[-1])
    return NOTE_NAMES[name[0]] + name.count("#") - name.count("b") + 12 * (octave + 1)


def freq(note):
    """'C5', 'F#4', 'Bb3' -> Hz (A4 = 440)."""
    return 440.0 * 2 ** ((midi(note) - 69) / 12)


def note_name(number):
    return f"{FLAT_NAMES[number % 12]}{number // 12 - 1}"


def parse(bars, name, key):
    """Bars of BAR_STEPS space-separated steps: a note (or notes joined by '+') starts, '-'
    holds, '.' rests. Returns ([(notes, start_step, length_steps)], total_steps)."""
    for i, bar in enumerate(bars):
        if len(bar.split()) != BAR_STEPS:
            raise MusicError(f"{name}: '{key}' bar {i + 1} has {len(bar.split())} steps, expected {BAR_STEPS}")
    steps = " ".join(bars).split()
    events = []
    for i, token in enumerate(steps):
        if token in ("-", "."):
            continue
        length = 1
        while i + length < len(steps) and steps[i + length] == "-":
            length += 1
        events.append((token.split("+"), i, length))
    return events, len(steps)


def map_notes(bars, change):
    """`bars` with every note replaced by change(note)."""
    out = []
    for bar in bars:
        out.append(" ".join(token if token in ("-", ".") else "+".join(change(n) for n in token.split("+")) for token in bar.split()))
    return out


def shift(bars, octaves):
    return map_notes(bars, lambda n: note_name(midi(n) + 12 * octaves))


def remap(bars, scale):
    """`bars` with every note snapped to the nearest pitch class of `scale` (semitones above
    C; a tie goes down)."""
    def snap(note):
        number = midi(note)
        for offset in (0, -1, 1, -2, 2):
            if (number + offset) % 12 in scale:
                return note_name(number + offset)
        raise MusicError(f"no note of scale {scale} near {note}")
    return map_notes(bars, snap)


_CACHE = {}


def partials_tone(hz, n, partials, attack, damp_from=None, damp_len=0):
    """Sum of sine partials (frequency multiple, amplitude, decay per second), n samples,
    with a linear attack and, from sample damp_from on, a damp_len-sample fade out."""
    key = ("partials", round(hz, 6), n, partials, attack, damp_from, damp_len)
    if key in _CACHE:
        return _CACHE[key]
    out = [0.0] * n
    for mult, amp, decay in partials:
        w = 2 * math.pi * hz * mult / RATE
        if w >= math.pi:
            continue
        r = math.exp(-decay / RATE)
        out = list(map(operator.add, out, [amp * math.sin(w * i) * r ** i for i in range(n)]))
    a = max(1, int(attack * RATE))
    for i in range(min(a, n)):
        out[i] *= i / a
    if damp_from is not None:
        for i in range(damp_from, n):
            out[i] *= max(0.0, 1.0 - (i - damp_from) / max(1, damp_len))
    _CACHE[key] = out
    return out


WAVETABLE_SIZE = 2048
VIBRATO_HZ = 5.5


def bowed_tone(hz, n, spectrum, attack, release, vibrato):
    """A sustained note (bowed or blown): the `spectrum` wavetable (partials under Nyquist
    only) read with a `vibrato` (depth, a fraction of the pitch) that starts after the
    attack, a linear attack and a linear release."""
    key = ("bowed", round(hz, 6), n, spectrum, attack, release, vibrato)
    if key in _CACHE:
        return _CACHE[key]
    table = [sum(amp * math.sin(2 * math.pi * mult * i / WAVETABLE_SIZE) for mult, amp in spectrum if hz * mult < RATE / 2)
             for i in range(WAVETABLE_SIZE)]
    a, r = max(1, int(attack * RATE)), max(1, int(release * RATE))
    out, phase = [], 0.0
    vib_w = 2 * math.pi * VIBRATO_HZ / RATE
    for i in range(n):
        depth = vibrato * min(1.0, i / (3 * a))
        phase = (phase + hz * (1.0 + depth * math.sin(vib_w * i)) / RATE) % 1.0
        out.append(table[int(phase * WAVETABLE_SIZE)] * min(1.0, i / a, (n - i) / r))
    _CACHE[key] = out
    return out


# Instruments. Plucked or struck: ("pluck", partials, attack s, ring s, damped): a ringing one
# sounds for `ring` seconds whatever its written length, a damped one stops at its length
# with a short fade. Sustained: ("bowed", spectrum, attack s, release s, vibrato depth).
VIBES = ("pluck", ((1, 1.0, 1.6), (4, 0.14, 7.0), (10, 0.03, 14.0)), 0.002, 1.1, False)
PIZZ_BASS = ("pluck", tuple((h, 1.0 / h ** 1.4, 5.0 + 3.0 * h) for h in range(1, 6)), 0.004, 0.45, False)
# Plucked near the end by a quill: bright, every partial present, damped on release.
HARPSICHORD = ("pluck", tuple((h, 0.8 / h ** 0.6, 3.0 + 2.5 * h) for h in range(1, 15)), 0.001, 0.0, True)
# Silk strings over a long body: a soft attack, the low partials ringing on.
KOTO = ("pluck", tuple((h, 1.0 / h ** 0.9 * (0.4 + abs(math.sin(math.pi * h * 0.23))), 2.5 + 3.0 * h) for h in range(1, 11)), 0.003, 1.3, False)
PIANO = ("pluck", tuple((h, 1.0 / h ** 1.3, 1.5 + 1.4 * h) for h in range(1, 9)), 0.003, 0.0, True)
LUTE = ("pluck", tuple((h, 0.9 / h ** 1.1 * abs(math.sin(math.pi * h * 0.18)), 3.0 + 2.2 * h) for h in range(1, 11)), 0.003, 0.9, False)
# Bowed strings: a saw-like spectrum with a body resonance bump.
STRINGS = ("bowed", tuple((h, (1.0 / h) * (1.0 + 0.8 * math.exp(-((h - 3) ** 2) / 2.0))) for h in range(1, 13)), 0.08, 0.12, 0.006)
# A shawm: a loud double reed, its middle partials strong (nasal), a little vibrato.
SHAWM = ("bowed", tuple((h, (1.0 / h ** 0.6) * (1.6 if 3 <= h <= 6 else 1.0)) for h in range(1, 15)), 0.03, 0.06, 0.004)
# An accordion: free reeds, odd partials strong, the bellows' slow wobble.
ACCORDION = ("bowed", tuple((h, 1.0 / h ** (0.8 if h % 2 else 1.4)) for h in range(1, 12)), 0.02, 0.05, 0.003)
# A hurdy-gurdy drone (Bosch): a buzzing bowed fifth, no vibrato.
DRONE = ("bowed", tuple((h, 1.0 / h ** 0.9) for h in range(1, 10)), 0.2, 0.2, 0.0)
DAMP_SECONDS = 0.05


def render_note(instrument, hz, seconds):
    if instrument[0] == "bowed":
        _, spectrum, attack, release, vibrato = instrument
        return bowed_tone(hz, max(1, int(seconds * RATE)), spectrum, attack, min(release, seconds * 0.4), vibrato)
    _, partials, attack, ring, damped = instrument
    if damped:
        n = int((seconds + DAMP_SECONDS) * RATE)
        return partials_tone(hz, n, partials, attack, int(seconds * RATE), int(DAMP_SECONDS * RATE))
    # A ringing note still fades over its last DAMP_SECONDS, so its cut never clicks.
    n = int(max(seconds, ring) * RATE)
    return partials_tone(hz, n, partials, attack, n - int(DAMP_SECONDS * RATE), int(DAMP_SECONDS * RATE))


def add_into(buf, samples, start, gain):
    """Adds samples * gain into buf from `start`, wrapping past the end to the start."""
    size = len(buf)
    start %= size
    pos = 0
    while pos < len(samples):
        at = (start + pos) % size
        count = min(len(samples) - pos, size - at)
        buf[at:at + count] = map(operator.add, buf[at:at + count], [s * gain for s in samples[pos:pos + count]])
        pos += count


def brush(rng):
    """A brush swept on a snare: a soft, slowly swelling and fading hiss."""
    n, y, out = int(0.18 * RATE), 0.0, []
    for i in range(n):
        y += 0.35 * (rng.uniform(-1.0, 1.0) - y)
        out.append(y * math.sin(math.pi * i / n) ** 2)
    return out


def ride(rng):
    """A ride cymbal tapped: bright high-passed noise with two metal partials, ringing short."""
    n, last, out = int(0.35 * RATE), 0.0, []
    for i in range(n):
        x = rng.uniform(-1.0, 1.0)
        metal = 0.3 * math.sin(2 * math.pi * 3150.0 * i / RATE) + 0.2 * math.sin(2 * math.pi * 4720.0 * i / RATE)
        out.append(((x - last) * 0.7 + metal) * math.exp(-9.0 * i / RATE))
        last = x
    return out


def tabor(rng):
    """A frame drum (tabor, taiko-like when low): a falling skin tone and a slap of noise."""
    n, phase, out = int(0.3 * RATE), 0.0, []
    for i in range(n):
        phase += 120.0 * (1.0 + 0.5 * math.exp(-25.0 * i / RATE)) / RATE
        out.append(math.sin(2 * math.pi * phase) * math.exp(-11.0 * i / RATE) + rng.uniform(-0.3, 0.3) * math.exp(-60.0 * i / RATE))
    return out


def woodblock(rng):
    """A wood block: a hollow knock."""
    n = int(0.08 * RATE)
    return [(math.sin(2 * math.pi * 900.0 * i / RATE) + 0.3 * math.sin(2 * math.pi * 2500.0 * i / RATE)) * math.exp(-55.0 * i / RATE) for i in range(n)]


# Chords: bass root, bass fifth, chord tones low to high.
CHORDS = {
    "Cm": ("C3", "G2", ("G3", "C4", "Eb4", "G4")),
    "G7": ("G2", "D3", ("F3", "B3", "D4", "G4")),
    "C7": ("C3", "G2", ("E3", "Bb3", "C4", "E4")),
    "Fm": ("F2", "C3", ("F3", "Ab3", "C4", "F4")),
    "Ab7": ("Ab2", "Eb3", ("Ab3", "C4", "Eb4", "Gb4")),
}

# The motif (8 bars of eight 8th-note steps, 4/4): a sneaking climb up C minor, a chromatic
# slip to the fifth, a step down from Ab, and a chromatic slide home.
MOTIF = [
    "G3 . C4 . Eb4 - D4 C4", "B3 - C4 - . . G3 .", "G3 . C4 . Eb4 - F4 Gb4", "G4 - - - . . . .",
    "Ab4 - G4 - F4 - Eb4 -", "D4 - Eb4 F4 G4 - . .", "C5 - B4 - Bb4 - A4 Ab4", "G4 - . . C4 - . .",
]
MOTIF_CHORDS = ["Cm", "G7", "Cm", "C7", "Fm", "G7", "Ab7", "Cm"]
# The answer: the same opening, then up to Ab and a long way down home.
ANSWER = [
    "G3 . C4 . Eb4 - D4 C4", "B3 - C4 - D4 - Eb4 -", "F4 . Ab4 . C5 - Bb4 Ab4", "G4 - - - Eb4 - . .",
    "F4 - Eb4 - D4 - C4 -", "B3 - C4 D4 Eb4 - G4 .", "F4 - Eb4 - D4 - B3 -", "C4 - - - - - . .",
]
ANSWER_CHORDS = ["Cm", "G7", "Fm", "Cm", "Fm", "G7", "G7", "Cm"]
TUNE = MOTIF + ANSWER
TUNE_CHORDS = MOTIF_CHORDS + ANSWER_CHORDS

# Scales (pitch classes above C) for the era versions.
HIRAJOSHI = (0, 2, 3, 7, 8)
DORIAN = (0, 2, 3, 5, 7, 9, 10)
AEOLIAN = (0, 2, 3, 5, 7, 8, 10)


def bass_bars(chords, style):
    """Per-bar bass: 'walk' (root, fifth, octave, a step back up on every beat), 'two' (root
    on 1, fifth on 3), 'eighths' (the root in 8ths, a continuo) or 'whole' (one long root)."""
    bars = []
    for name in chords:
        root, fifth = CHORDS[name][0], CHORDS[name][1]
        if style == "walk":
            bars.append(f"{root} - {fifth} - {note_name(midi(root) + 12)} - {note_name(midi(fifth) + 2)} -")
        elif style == "two":
            bars.append(f"{root} - . . {fifth} - . .")
        elif style == "eighths":
            bars.append(f"{root} {root} {fifth} {fifth} {root} {root} {fifth} {root}")
        elif style == "whole":
            bars.append(f"{root} - - - - - - -")
        else:
            raise MusicError(f"unknown bass style '{style}'")
    return bars


def chord_bars(chords, style):
    """Per-bar accompaniment: 'oompah' (the chord on 2 and 4), 'arp' (the chord picked up
    and down in 8ths), 'swirl' (the chord's tones circling in 8ths, two at a time), 'comp'
    (a chord on the off-beat of 2 and on 4) or 'drone' (C and G held under everything)."""
    bars = []
    for name in chords:
        t0, t1, t2, t3 = CHORDS[name][2]
        chord = f"{t0}+{t1}+{t2}"
        if style == "oompah":
            bars.append(f". . {chord} - . . {chord} -")
        elif style == "arp":
            bars.append(f"{t0} {t1} {t2} {t3} {t2} {t1} {t2} {t1}")
        elif style == "swirl":
            bars.append(f"{t1} {t2} {t3} {t2} {t0} {t2} {t3} {t1}")
        elif style == "comp":
            bars.append(f". . . {chord} - . {chord} .")
        elif style == "drone":
            bars.append("C3+G3 - - - - - - -")
        else:
            raise MusicError(f"unknown chord style '{style}'")
    return bars


def track(name, bpm, parts, chords, *, swing=0.0, perc=None):
    """A loop at `bpm` quarter notes a minute: `parts` are (instrument, bars, gain), one
    bar per chord; `swing` delays every off-beat 8th by that share of a step; `perc` is the
    percussion bars (BAR_STEPS characters: 'b' brush, 'r' ride, 't' tabor, 'w' wood block,
    '.' none; None: no percussion)."""
    return {"name": name, "step": 60.0 / bpm / 2, "parts": parts, "chords": chords, "swing": swing,
            "perc": perc if perc is not None else ["." * BAR_STEPS] * len(chords)}


CAPER = track("caper", 126, [
    (VIBES, shift(TUNE, 1), 0.34),
    (PIANO, chord_bars(TUNE_CHORDS, "comp"), 0.1),
    (PIZZ_BASS, bass_bars(TUNE_CHORDS, "walk"), 0.4),
], TUNE_CHORDS, swing=0.22, perc=["r.rbr.rb"] * 16)
WING_01 = track("wing_01", 100, [
    (HARPSICHORD, shift(TUNE, 1), 0.3),
    (HARPSICHORD, chord_bars(TUNE_CHORDS, "arp"), 0.13),
    (HARPSICHORD, bass_bars(TUNE_CHORDS, "eighths"), 0.18),
], TUNE_CHORDS)
WING_02 = track("wing_02", 84, [
    (KOTO, remap(shift(TUNE, 1), HIRAJOSHI), 0.36),
    (KOTO, remap(chord_bars(TUNE_CHORDS, "arp"), HIRAJOSHI), 0.1),
    (KOTO, bass_bars(["Cm"] * 16, "two"), 0.28),
], TUNE_CHORDS, perc=["t.......", "t...t..."] * 8)
WING_03 = track("wing_03", 132, [
    (ACCORDION, shift(TUNE, 1), 0.2),
    (PIANO, chord_bars(TUNE_CHORDS, "oompah"), 0.14),
    (PIANO, bass_bars(TUNE_CHORDS, "two"), 0.3),
], TUNE_CHORDS, swing=0.12, perc=["..w...w."] * 16)
WING_04 = track("wing_04", 96, [
    (STRINGS, shift(TUNE, 1), 0.26),
    (STRINGS, chord_bars(TUNE_CHORDS, "swirl"), 0.08),
    (PIZZ_BASS, bass_bars(TUNE_CHORDS, "two"), 0.4),
], TUNE_CHORDS)
WING_05 = track("wing_05", 112, [
    (SHAWM, remap(shift(TUNE, 1), DORIAN), 0.18),
    (DRONE, chord_bars(TUNE_CHORDS, "drone"), 0.07),
], TUNE_CHORDS, perc=["t..t.t..", "t..t.tt."] * 8)
WING_06 = track("wing_06", 92, [
    (LUTE, remap(shift(TUNE, 1), AEOLIAN), 0.36),
    (LUTE, remap(chord_bars(TUNE_CHORDS, "arp"), AEOLIAN), 0.13),
    (LUTE, remap(bass_bars(TUNE_CHORDS, "two"), AEOLIAN), 0.26),
], TUNE_CHORDS)
RESULTS = track("results", 84, [
    (VIBES, shift(ANSWER, 1), 0.36),
    (PIANO, chord_bars(ANSWER_CHORDS, "comp"), 0.1),
    (PIZZ_BASS, bass_bars(ANSWER_CHORDS, "whole"), 0.4),
], ANSWER_CHORDS, swing=0.22, perc=["b...b..."] * 8)
TRACKS = (CAPER, WING_01, WING_02, WING_03, WING_04, WING_05, WING_06, RESULTS)
PERC_GAINS = {"b": 0.05, "r": 0.035, "t": 0.2, "w": 0.06}


def render(spec):
    """One loop of `spec` as float samples."""
    step = spec["step"]
    name = spec["name"]
    total = len(spec["chords"]) * BAR_STEPS
    size = int(round(total * step * RATE))
    buf = [0.0] * size

    def at(start):
        swung = spec["swing"] if start % 2 == 1 else 0.0
        return int(round((start + swung) * step * RATE))

    for index, (instrument, bars, gain) in enumerate(spec["parts"]):
        events, steps = parse(bars, name, f"part {index + 1}")
        if steps != total:
            raise MusicError(f"{name}: part {index + 1} is {steps} steps, expected {total}")
        for notes, start, length in events:
            for i, note in enumerate(notes):
                # A strummed chord: each string a hair after the one below it.
                add_into(buf, render_note(instrument, freq(note), length * step * 0.92), at(start) + i * int(0.008 * RATE), gain)
    hits = "".join(spec["perc"])
    if len(hits) != total:
        raise MusicError(f"{name}: 'perc' is {len(hits)} steps, expected {total}")
    rng = random.Random(f"music/{name}")
    kit = {"b": brush(rng), "r": ride(rng), "t": tabor(rng), "w": woodblock(rng)}
    for i, hit in enumerate(hits):
        if hit in kit:
            add_into(buf, kit[hit], at(i), PERC_GAINS[hit])
        elif hit != ".":
            raise MusicError(f"{name}: unknown percussion '{hit}'")
    return buf


def loudness(samples):
    """The integrated loudness of `samples` (full scale 1.0) in LUFS: BS.1770 K-weighting,
    then the gated mean square of LOUDNESS_BLOCK blocks."""
    squares = [y * y for y in k_weighted(samples, RATE)]
    block, hop = int(LOUDNESS_BLOCK * RATE), int(LOUDNESS_HOP * RATE)
    sums = [0.0]
    for v in squares:
        sums.append(sums[-1] + v)
    means = [(sums[i + block] - sums[i]) / block for i in range(0, len(squares) - block + 1, hop)]
    gated = [m for m in means if -0.691 + 10 * math.log10(max(m, 1e-12)) > -70.0]
    if not gated:
        return -70.0
    relative = -0.691 + 10 * math.log10(sum(gated) / len(gated)) - 10.0
    gated = [m for m in gated if -0.691 + 10 * math.log10(max(m, 1e-12)) > relative]
    return -0.691 + 10 * math.log10(sum(gated) / len(gated))


def to_pcm(samples, name):
    """16-bit PCM of `samples` scaled to LOUDNESS LUFS; a loop that would pass PEAK there is
    an error (lower its voices instead)."""
    gain = 10 ** ((LOUDNESS - loudness(samples)) / 20)
    top = max(abs(s) for s in samples) * gain
    if top > PEAK:
        raise MusicError(f"{name}: at {LOUDNESS} LUFS it peaks at {top:.3f}, above PEAK {PEAK}")
    return b"".join(struct.pack("<h", int(s * gain * 32767)) for s in samples)


def render_all():
    """{track name: (16-bit mono PCM bytes, sample count)} for every track."""
    rendered = {}
    for spec in TRACKS:
        pcm = to_pcm(render(spec), spec["name"])
        rendered[spec["name"]] = (pcm, len(pcm) // 2)
    return rendered


def file_sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def lock_entry(pcm, samples, mp3):
    return {"samples": samples, "seconds": round(samples / RATE, 3), "sha256": hashlib.sha256(pcm).hexdigest(),
            "mp3_sha256": file_sha(mp3), "mp3_bytes": mp3.stat().st_size}


def import_has_loop(mp3):
    path = Path(str(mp3) + ".import")
    return path.exists() and "loop=true" in path.read_text().splitlines()


def check():
    try:
        lock = json.loads(LOCK.read_text())
    except (OSError, ValueError) as e:
        raise MusicError(f"cannot read {LOCK.relative_to(ROOT)}: {e}; run python3 tools/music.py")
    problems = []
    rendered = render_all()
    if sorted(lock) != sorted(rendered):
        problems.append(f"{LOCK.relative_to(ROOT)} lists {sorted(lock)}, the tracks are {sorted(rendered)}")
    total_bytes = 0
    for name, (pcm, samples) in rendered.items():
        want = lock.get(name, {})
        if want.get("samples") != samples:
            problems.append(f"{name}: the loop is {samples} samples, the lock says {want.get('samples')}")
        if want.get("sha256") != hashlib.sha256(pcm).hexdigest():
            problems.append(f"{name}: the rendered audio differs from the lock, run python3 tools/music.py")
        mp3 = OUT_DIR / f"{name}.mp3"
        if not mp3.exists():
            problems.append(f"{mp3.relative_to(ROOT)} missing, run python3 tools/music.py")
            continue
        total_bytes += mp3.stat().st_size
        if want.get("mp3_bytes") != mp3.stat().st_size or want.get("mp3_sha256") != file_sha(mp3):
            problems.append(f"{mp3.relative_to(ROOT)} differs from the MP3 the lock records, run python3 tools/music.py")
        if not import_has_loop(mp3):
            problems.append(f"{mp3.relative_to(ROOT)}.import does not switch the loop on (loop=true)")
    for path in sorted(OUT_DIR.glob("*.mp3")):
        if path.stem not in rendered:
            problems.append(f"{path.relative_to(ROOT)} is stale: no track makes it any more")
    if total_bytes > MAX_TOTAL_BYTES:
        problems.append(f"the MP3s total {total_bytes} bytes, over {MAX_TOTAL_BYTES}")
    if problems:
        raise MusicError("\n".join(problems))
    print(f"music: OK ({len(rendered)} loops, {total_bytes} bytes of MP3)")


def check_decode(ffmpeg, mp3, samples):
    """Decodes `mp3` the gapless way (as Godot does) and confirms it is exactly `samples` long."""
    result = subprocess.run([ffmpeg, "-v", "error", "-i", str(mp3), "-f", "s16le", "-ac", "1", "-"], capture_output=True)
    if result.returncode != 0:
        stderr = result.stderr.decode(errors="replace").strip()
        raise MusicError(f"ffmpeg failed to decode {mp3} (exit status {result.returncode}): {stderr}")
    raw = result.stdout
    if len(raw) // 2 != samples:
        raise MusicError(f"{mp3} decodes to {len(raw) // 2} samples, expected {samples}; is lame still writing its LAME tag?")


def write_import(mp3):
    """Switches Godot's plain loop on in <mp3>.import, keeping whatever else Godot wrote there."""
    path = Path(str(mp3) + ".import")
    params = {"loop": "true", "loop_offset": "0", "bpm": "0", "beat_count": "0", "bar_beats": "4"}
    if path.exists():
        lines, seen = [], set()
        for line in path.read_text().splitlines():
            key = line.split("=", 1)[0]
            if key in params:
                line = f"{key}={params[key]}"
                seen.add(key)
            lines.append(line)
        lines += [f"{k}={v}" for k, v in params.items() if k not in seen]
        text = "\n".join(lines) + "\n"
    else:
        res = "res://" + mp3.resolve().relative_to(PROJECT).as_posix()
        text = (f'[remap]\n\nimporter="mp3"\ntype="AudioStreamMP3"\n\n[deps]\n\nsource_file="{res}"\n\n[params]\n\n'
                + "".join(f"{k}={v}\n" for k, v in params.items()))
    path.write_text(text)


def generate():
    lame, ffmpeg = shutil.which("lame"), shutil.which("ffmpeg")
    if lame is None or ffmpeg is None:
        raise MusicError("lame and ffmpeg are needed on PATH to encode (Homebrew: brew install lame ffmpeg)")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lock = {}
    with tempfile.TemporaryDirectory() as tmp:
        for name, (pcm, samples) in render_all().items():
            wav = Path(tmp) / f"{name}.wav"
            with wave.open(str(wav), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(pcm)
            mp3 = OUT_DIR / f"{name}.mp3"
            # CBR, no ID3 tags. Keep the LAME tag (no -t): it makes the decoded file one loop long.
            result = subprocess.run([lame, "--quiet", "-m", "m", "-b", "80", "--noreplaygain", str(wav), str(mp3)],
                                    capture_output=True, text=True)
            if result.returncode != 0:
                raise MusicError(f"lame failed for {mp3}: {result.stderr.strip()}")
            check_decode(ffmpeg, mp3, samples)
            write_import(mp3)
            lock[name] = lock_entry(pcm, samples, mp3)
            print(f"music: wrote {mp3.relative_to(ROOT)} ({samples / RATE:.3f}s loop, {samples} samples, {mp3.stat().st_size} bytes)")
    for path in sorted(OUT_DIR.glob("*.mp3")):
        if path.stem not in lock:
            raise MusicError(f"{path.relative_to(ROOT)} is stale: no track makes it any more; delete it and its .import")
    LOCK.write_text(json.dumps(lock, indent=2) + "\n")
    print(f"music: wrote {LOCK.relative_to(ROOT)}")


def main():
    try:
        if sys.argv[1:] == ["--check"]:
            check()
        elif not sys.argv[1:]:
            generate()
        else:
            print(__doc__, file=sys.stderr)
            return 2
    except MusicError as e:
        print(f"music: error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
