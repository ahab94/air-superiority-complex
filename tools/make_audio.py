#!/usr/bin/env python3
"""Synthesizes all of Air Superiority Complex's sound: cannons, explosions,
missiles, warnings, a few comedy stings, ambience loops, and three music
loops. Original sounds built from oscillators and noise, no samples,
Python standard library only.

    python3 tools/make_audio.py   ->  audio/sfx/*.wav, audio/loops/*.wav, audio/music/*.wav

Deterministic: running it again rebuilds identical files. Sounds that repeat
a lot (cannon fire, ~12 a second) are kept short, dark and quiet on purpose.
"""
import math
import os
import random

import synth
from synth import Track, at, cat, hz, layer, noise, tone

OUT = os.path.join(synth.HERE, "..", "audio")


# --- building blocks ----------------------------------------------------------

def thump(f0=140, f1=45, dur=0.25, vol=0.6, decay=0.08):
    """A falling sine: the body of kicks and explosions."""
    return tone(f0, dur, "sine", vol, attack=0.001, decay=decay, glide_to=f1)


def blast(dur, vol, lo_from, lo_to, decay, seed):
    """Noise whose brightness falls away: the roar of an explosion."""
    return noise(dur, vol, decay=decay, lowpass=lo_from, sweep_to=lo_to, seed=seed, attack=0.002)


def beep(freq, dur=0.07, vol=0.3, shape="square"):
    return tone(freq, dur, shape, vol, attack=0.002, release=0.01, lowpass=4000)


def brass(note, dur, vol=0.2, attack=0.03, lowpass=1800):
    """Detuned saws through a lowpass: a synth-brass stab."""
    f = hz(note) if isinstance(note, str) else note
    return tone(f, dur, "saw", vol, attack=attack, decay=dur * 0.8, release=0.06, lowpass=lowpass, detune=0.006)


def bell(note, dur=0.8, vol=0.2, decay=0.25):
    f = hz(note) if isinstance(note, str) else note
    return layer(tone(f, dur, "sine", vol, attack=0.002, decay=decay),
                 tone(f * 2.76, dur * 0.4, "sine", vol * 0.3, attack=0.002, decay=decay * 0.3))


# --- sound effects ------------------------------------------------------------

def sfx():
    s = {}
    # Our cannon: a tight low thump with a dark crack. Fires ~12x a second,
    # so it's short and kept down in the mix by sound.gd.
    s["gun"] = layer(thump(160, 70, 0.07, 0.6, 0.02), noise(0.06, 0.5, decay=0.012, lowpass=2200, seed=1))
    # Their cannon: thinner and further away.
    s["egun"] = layer(thump(220, 110, 0.06, 0.4, 0.015), noise(0.05, 0.35, decay=0.01, lowpass=3200, highpass=400, seed=2))
    # A round hitting a jet: a metallic tick and a small explosive crack.
    s["hit"] = layer(tone(1400, 0.08, "square", 0.15, decay=0.012, glide_to=700, lowpass=5000),
                     noise(0.12, 0.4, decay=0.03, lowpass=3000, seed=3))
    # Us getting hit: a heavier clank and crunch.
    s["hurt"] = layer(tone(320, 0.2, "square", 0.2, decay=0.05, glide_to=180, lowpass=1500),
                      noise(0.25, 0.6, decay=0.06, lowpass=1800, seed=4), thump(120, 50, 0.2, 0.4, 0.05))
    # Explosions: a short one for fighters, a long rolling one for big things.
    s["boom"] = layer(blast(1.1, 0.8, 2400, 160, 0.28, 5), thump(90, 35, 0.6, 0.7, 0.18),
                      at(0.05, noise(0.5, 0.25, decay=0.12, highpass=2500, seed=6)))
    s["bigboom"] = layer(blast(2.2, 0.9, 1800, 90, 0.6, 7), thump(70, 25, 1.4, 0.9, 0.45),
                         at(0.12, blast(1.4, 0.4, 1200, 120, 0.4, 8)), at(0.3, blast(1.0, 0.3, 900, 100, 0.3, 9)))
    # Missile launch: an ignition crack, then a roaring whoosh that brightens.
    s["missile"] = layer(noise(0.08, 0.5, decay=0.02, lowpass=4000, seed=10),
                         noise(1.1, 0.55, decay=0.5, lowpass=500, sweep_to=3500, seed=11, attack=0.03),
                         tone(90, 0.9, "saw", 0.12, decay=0.4, lowpass=400))
    # A SAM leaving its rail on the ground: deeper, longer, more menacing.
    s["sam"] = layer(thump(80, 30, 0.6, 0.6, 0.2),
                     noise(1.6, 0.6, decay=0.8, lowpass=300, sweep_to=2600, seed=12, attack=0.05))
    # Radar: the growl while locking, the chirp when a lock is made.
    s["lock_tone"] = beep(880, 0.06, 0.22)
    s["lock_ok"] = layer(beep(1320, 0.06, 0.25), at(0.07, beep(1760, 0.09, 0.25)))
    # MISSILE LOCK warning (loops while something is locking or chasing us).
    warn = []
    for k in range(4):
        warn += tone(1250 if k % 2 == 0 else 950, 0.11, "square", 0.22, attack=0.002, release=0.01, lowpass=3500)
        warn += [0.0] * int(0.015 * synth.SR)
    s["warning"] = warn
    # Flares: a pop and a fizzing hiss.
    s["flare"] = layer(noise(0.05, 0.6, decay=0.01, lowpass=3000, seed=13),
                       at(0.02, noise(0.7, 0.35, decay=0.3, highpass=3500, seed=14)),
                       at(0.06, noise(0.6, 0.2, decay=0.25, highpass=1500, lowpass=6000, seed=15)))
    # A missile fooled by a flare and lost: a small, far-off pop.
    s["pop"] = layer(thump(200, 80, 0.2, 0.3, 0.05), noise(0.3, 0.3, decay=0.08, lowpass=1800, seed=16))
    # Flak: a dull, heavy WHUMP with a crack on top.
    s["flak"] = layer(thump(70, 30, 0.8, 0.8, 0.22), blast(0.8, 0.6, 1100, 120, 0.2, 17),
                      noise(0.05, 0.4, decay=0.01, highpass=2000, seed=18))
    # Wreck hitting the sea far below.
    s["splash"] = layer(noise(0.9, 0.5, decay=0.3, lowpass=1600, sweep_to=400, seed=19, attack=0.01),
                        at(0.05, noise(0.6, 0.2, decay=0.25, highpass=3000, seed=20)))
    # Spy camera: shutter click-clack and a tiny motor wind.
    s["shutter"] = layer(noise(0.02, 0.6, decay=0.005, highpass=2500, seed=21),
                         at(0.06, noise(0.03, 0.5, decay=0.008, highpass=1800, seed=22)),
                         at(0.1, tone(600, 0.18, "square", 0.05, glide_to=900, lowpass=2500)))
    s["missed"] = layer(beep(500, 0.09, 0.15, "tri"), at(0.1, beep(380, 0.14, 0.15, "tri")))
    # Engine overheat: a two-tone alarm.
    s["overheat"] = cat(*[tone(700 if k % 2 == 0 else 520, 0.14, "saw", 0.18, lowpass=2500, release=0.02) for k in range(6)])
    # Comedy: the Ministry of Claims' cash register (combos, changing sides).
    s["kaching"] = layer(noise(0.05, 0.4, decay=0.01, highpass=1500, seed=23),
                         at(0.04, bell(2093, 0.9, 0.22, 0.3)), at(0.04, bell(2637, 0.9, 0.18, 0.3)),
                         at(0.02, tone(180, 0.12, "square", 0.12, decay=0.04, lowpass=900)))
    # A contract stamp (THUNK) before the ka-ching.
    s["stamp"] = layer(thump(130, 60, 0.25, 0.7, 0.05), noise(0.12, 0.4, decay=0.03, lowpass=1200, seed=24))
    # Tea: a cup set on a saucer, and a polite sip.
    s["tea"] = layer(bell(3100, 0.5, 0.12, 0.12), at(0.04, bell(4200, 0.4, 0.08, 0.08)),
                     at(0.35, noise(0.45, 0.15, decay=0.2, lowpass=2500, highpass=600, seed=25, attack=0.08)))
    # Wave clear / approach: short synth-brass stingers.
    s["clear"] = layer(brass("E4", 0.35, 0.18), brass("B4", 0.35, 0.14), at(0.18, brass("E5", 0.6, 0.2)))
    s["approach"] = layer(*[at(i * 0.14, brass(n, 0.5, 0.16)) for i, n in enumerate(["C4", "E4", "G4", "C5"])])
    # Mission complete: a proper fanfare. Mission failed: the sad trombone.
    s["win"] = layer(*[at(i * 0.16, brass(n, 0.3, 0.18)) for i, n in enumerate(["G4", "C5", "E5"])],
                     at(0.5, layer(brass("G5", 1.4, 0.22, 0.05), brass("E5", 1.4, 0.16, 0.05), brass("C5", 1.4, 0.16, 0.05))),
                     at(0.5, thump(110, 50, 0.5, 0.4, 0.15)))
    s["lose"] = cat(*[tone(hz(n), d, "saw", 0.22, attack=0.03, release=0.05, lowpass=1100, detune=0.004,
                           glide_to=hz(n) * (0.94 if i == 3 else 0.99))
                      for i, (n, d) in enumerate([("D4", 0.35), ("C#4", 0.35), ("C4", 0.35), ("B3", 1.2)])])
    # Rescue, join, respawn: friendly little chirps.
    s["rescue"] = layer(*[at(i * 0.08, bell(n, 0.4, 0.16, 0.12)) for i, n in enumerate(["C6", "E6", "G6", "C7"])])
    s["join"] = layer(noise(0.04, 0.3, decay=0.01, highpass=2000, seed=26), at(0.05, beep(1200, 0.06, 0.2)), at(0.12, beep(1600, 0.08, 0.2)))
    s["ui"] = beep(900, 0.05, 0.18, "tri")
    return s


# --- ambience loops (seamless) ---------------------------------------------------

def engine_loop(seconds=4.0):
    """Jet engine from inside the cockpit: a low roar with a turbine whine."""
    t = Track(seconds, loop=True)
    t.add(0, noise(seconds, 0.6, decay=None, lowpass=220, seed=30))
    t.add(0, noise(seconds, 0.12, decay=None, lowpass=2000, highpass=800, seed=31))
    # The whine: whole cycles fit the loop exactly, so it wraps cleanly.
    f = round(1650 * seconds) / seconds
    t.add(0, tone(f, seconds, "sine", 0.03, attack=0.0, release=0.0))
    f2 = round(55 * seconds) / seconds
    t.add(0, tone(f2, seconds, "saw", 0.08, attack=0.0, release=0.0, lowpass=200))
    return t.buf


def rain_loop(seconds=5.0):
    t = Track(seconds, loop=True)
    t.add(0, noise(seconds, 0.5, decay=None, lowpass=5000, highpass=900, seed=32))
    rng = random.Random(33)
    for _ in range(120):
        t.add(rng.uniform(0, seconds), noise(0.03, rng.uniform(0.1, 0.3), decay=0.008, highpass=2500, seed=rng.randrange(9999)))
    return t.buf


def wind_loop(seconds=6.0):
    t = Track(seconds, loop=True)
    n = noise(seconds, 0.6, decay=None, lowpass=700, highpass=120, seed=34)
    # Slow gusts: a loud-quiet swell that completes whole cycles in the loop.
    for i in range(len(n)):
        n[i] *= 0.55 + 0.45 * math.sin(2 * math.pi * i / len(n) * 2) ** 2
    t.add(0, n)
    return t.buf


# --- music ------------------------------------------------------------------------

def kick(vol=0.5):
    return layer(thump(150, 45, 0.25, vol, 0.07), noise(0.01, vol * 0.3, decay=0.003, highpass=2000, seed=40))


def snare(vol=0.3, seed=41):
    return layer(noise(0.2, vol, decay=0.06, lowpass=6000, highpass=900, seed=seed), tone(190, 0.1, "tri", vol * 0.5, decay=0.04))


def hat(vol=0.08, seed=42, open_=False):
    return noise(0.2 if open_ else 0.05, vol, decay=0.08 if open_ else 0.015, highpass=7000, seed=seed)


def combat_cold_war():
    """Chapter 1 battle theme: E minor, 132 BPM, driving bass, brass stabs,
    and a heroic line every other phrase. 16 bars, loops."""
    bpm = 132
    beat = 60 / bpm
    bar = 4 * beat
    chords = ["Em", "C", "D", "Bm", "Em", "C", "Am", "B",
              "Em", "C", "D", "Bm", "C", "D", "Em", "Em"]
    roots = {"Em": "E2", "C": "C2", "D": "D2", "Bm": "B1", "Am": "A1", "B": "B1"}
    tri = {"Em": ["E4", "G4", "B4"], "C": ["C4", "E4", "G4"], "D": ["D4", "F#4", "A4"],
           "Bm": ["B3", "D4", "F#4"], "Am": ["A3", "C4", "E4"], "B": ["B3", "D#4", "F#4"]}
    melody = {8: [("B4", 1), ("E5", 1), ("G5", 2)], 9: [("F#5", 1.5), ("E5", 0.5), ("C5", 2)],
              10: [("D5", 1), ("F#5", 1), ("A5", 2)], 11: [("G5", 1.5), ("F#5", 0.5), ("D5", 2)],
              12: [("E5", 1), ("G5", 1), ("C6", 2)], 13: [("B5", 1), ("A5", 1), ("F#5", 2)],
              14: [("G5", 2), ("F#5", 1), ("D#5", 1)], 15: [("E5", 4)]}
    length = len(chords) * bar
    mix = Track(length, loop=True)
    for b, ch in enumerate(chords):
        t0 = b * bar
        r = hz(roots[ch])
        # Bass: galloping eighths with an octave jump.
        for k in range(8):
            f = r * (2 if k in (3, 7) else 1)
            mix.add(t0 + k * beat / 2, tone(f, beat * 0.45, "saw", 0.22, attack=0.003, decay=0.12, lowpass=500))
        # Drums: kick on 1 and 3 (and the "and" of 4), snare on 2 and 4, eighth hats.
        for k in (0, 2):
            mix.add(t0 + k * beat, kick())
        mix.add(t0 + 3.5 * beat, kick(0.35))
        for k in (1, 3):
            mix.add(t0 + k * beat, snare(0.32, seed=41 + b))
        for k in range(8):
            mix.add(t0 + k * beat / 2, hat(0.07 if k % 2 else 0.1, seed=50 + k))
        # Brass stabs on the chord.
        for k in (0, 1.5, 3):
            for n in tri[ch]:
                mix.add(t0 + k * beat, brass(n, beat * 0.4, 0.07, attack=0.01, lowpass=2200))
        # Melody in the second half.
        if b in melody:
            t = t0
            for note, beats in melody[b]:
                mix.add(t, tone(hz(note), beats * beat * 0.95, "saw", 0.1, attack=0.02, decay=beats * beat, lowpass=3000, detune=0.004))
                t += beats * beat
    return mix.buf


def combat_subcontinent():
    """Chapter 2 battle theme: a drone on D, tabla-style hand drums, a plucked
    lead that slides between notes, over a backbeat. 120 BPM, 16 bars, loops."""
    bpm = 120
    beat = 60 / bpm
    bar = 4 * beat
    length = 16 * bar
    mix = Track(length, loop=True)
    # Drone: D and A, slowly shimmering (whole number of cycles, so it loops).
    for note, vol in (("D2", 0.08), ("A2", 0.06), ("D3", 0.04)):
        f = round(hz(note) * length) / length
        mix.add(0, tone(f, length, "saw", vol, attack=0.0, release=0.0, lowpass=900, detune=0.003))
    # Hand drums: high "na" and bending low "ge", in a 16th-note pattern.
    pattern = "G.n.n.G.n.G.nn.n"
    rng = random.Random(60)
    for b in range(16):
        t0 = b * bar
        for k, c in enumerate(pattern):
            t = t0 + k * beat / 4
            if c == "n":
                mix.add(t, layer(tone(560 + rng.uniform(-15, 15), 0.12, "sine", 0.12, attack=0.001, decay=0.04),
                                 noise(0.03, 0.06, decay=0.01, highpass=3000, seed=rng.randrange(999))))
            elif c == "G":
                mix.add(t, tone(95, 0.35, "sine", 0.22, attack=0.002, decay=0.14, glide_to=150))
        mix.add(t0, kick(0.4))
        mix.add(t0 + 2 * beat, kick(0.4))
        for k in (1, 3):
            mix.add(t0 + k * beat, snare(0.22, seed=70 + b))
    # Plucked lead with slides (all original), from bar 4.
    phrase = [("D5", 1, None), ("Eb5", 0.5, None), ("F#5", 0.5, None), ("G5", 1, "A5"), ("A5", 1, None),
              ("Bb5", 0.5, None), ("A5", 0.5, None), ("G5", 1, None), ("F#5", 1, "G5"), ("Eb5", 1, None), ("D5", 2, None)]
    for start_bar in (4, 10):
        t = start_bar * bar
        for note, beats, slide in phrase:
            f = hz(note)
            g = hz(slide) if slide else None
            mix.add(t, tone(f, beats * beat, "saw", 0.12, attack=0.003, decay=0.22, lowpass=2600, glide_to=g))
            t += beats * beat
    # A bass pulse to keep it an action piece.
    for b in range(16):
        for k in range(4):
            mix.add(b * bar + k * beat, tone(hz("D2"), beat * 0.4, "saw", 0.16, attack=0.003, decay=0.1, lowpass=400))
    return mix.buf


def lounge():
    """The bar where Ace tells his stories: a slow swing on electric piano,
    walking bass and brushes. F major ii-V-I, 92 BPM, 8 bars, loops."""
    bpm = 92
    beat = 60 / bpm
    bar = 4 * beat
    swing = beat * 0.66
    prog = [("Gm7", ["G3", "Bb3", "D4", "F4"], ["G2", "A2", "Bb2", "B2"]),
            ("C7", ["C4", "E4", "G4", "Bb4"], ["C3", "Bb2", "A2", "G2"]),
            ("Fmaj7", ["F3", "A3", "C4", "E4"], ["F2", "G2", "A2", "C3"]),
            ("Dm7", ["D4", "F4", "A4", "C5"], ["D3", "C3", "A2", "F2"]),
            ("Gm7", ["G3", "Bb3", "D4", "F4"], ["G2", "Bb2", "D3", "Bb2"]),
            ("C7", ["C4", "E4", "G4", "Bb4"], ["C3", "E3", "G2", "E2"]),
            ("Fmaj7", ["F3", "A3", "C4", "E4"], ["F2", "A2", "C3", "A2"]),
            ("C7", ["C4", "E4", "G4", "Bb4"], ["C3", "B2", "Bb2", "G2"])]
    length = len(prog) * bar
    mix = Track(length, loop=True)
    keys = Track(length, loop=True)
    for b, (_, chord, walk) in enumerate(prog):
        t0 = b * bar
        # Electric piano: soft chord on 1 and a swung push before 3.
        for when, vol in ((0, 0.07), (swing + beat, 0.05)):
            for n in chord:
                keys.add(t0 + when, layer(tone(hz(n), beat * 1.6, "sine", vol, attack=0.005, decay=0.7, tremolo=0.25, tremolo_hz=5),
                                          tone(hz(n) * 2, beat * 0.8, "tri", vol * 0.15, attack=0.003, decay=0.2)))
        # Walking bass, one note a beat.
        for k, n in enumerate(walk):
            mix.add(t0 + k * beat, tone(hz(n), beat * 0.9, "tri", 0.26, attack=0.008, decay=0.35, lowpass=600))
        # Brushes: a soft swish on 2 and 4, a ride pattern swung.
        for k in (1, 3):
            mix.add(t0 + k * beat, noise(0.3, 0.1, decay=0.12, highpass=2000, lowpass=7000, seed=80 + b * 4 + k, attack=0.03))
        for k in range(4):
            mix.add(t0 + k * beat, hat(0.05, seed=90 + k, open_=True))
            if k % 2 == 1:
                mix.add(t0 + k * beat + swing, hat(0.035, seed=95 + k))
    keys.echo(beat * 0.75, feedback=0.25, mix=0.2)
    mix.mix(keys)
    return mix.buf


def main():
    for name, samples in sfx().items():
        synth.write_wav(os.path.join(OUT, "sfx", name + ".wav"), samples)
    for name, fn in (("engine", engine_loop), ("rain", rain_loop), ("wind", wind_loop)):
        synth.write_wav(os.path.join(OUT, "loops", name + ".wav"), fn(), peak=0.7)
    synth.SR = 22050
    synth.write_wav(os.path.join(OUT, "music", "lounge.wav"), lounge(), peak=0.6)
    synth.write_wav(os.path.join(OUT, "music", "cold_war.wav"), combat_cold_war(), peak=0.6)
    synth.write_wav(os.path.join(OUT, "music", "subcontinent.wav"), combat_subcontinent(), peak=0.6)


if __name__ == "__main__":
    main()
