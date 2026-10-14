#!/usr/bin/env python3
"""Comedy sound effects for the marketing videos (not used in the game), plus
the game's own music copied in as background beds. Original, synthesized with
tools/synth.py (stingers adapted from Cardboard Espionage Action's videos).

    python3 tools/video/make_video_audio.py   ->  build/video_audio/*.wav
"""
import math
import os
import random
import shutil
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import synth as A  # noqa: E402

OUT = os.path.join(A.HERE, "..", "build", "video_audio")
MUSIC = os.path.join(A.HERE, "..", "audio", "music")
tone, noise, layer, at, hz = A.tone, A.noise, A.layer, A.at, A.hz


def vibrato(freq, dur, vol, depth, rate, shape="sine", glide_to=None, decay=None, lowpass=None):
    """A note with wobble: the basis of slide whistles and trombones."""
    n = int(dur * A.SR)
    out = [0.0] * n
    p = 0.0
    y = 0.0
    k = 1 - math.exp(-A.TAU * lowpass / A.SR) if lowpass else None
    for i in range(n):
        t = i / A.SR
        f = freq if glide_to is None else freq * (glide_to / freq) ** (t / dur)
        f *= 1 + depth * math.sin(A.TAU * rate * t)
        p = (p + f / A.SR) % 1.0
        s = A._wave(shape, p)
        if k:
            y += k * (s - y)
            s = y
        env = min(1.0, t / 0.02) * (math.exp(-t / decay) if decay else 1.0)
        env *= min(1.0, (dur - t) / 0.04)
        out[i] = s * env * vol
    return out


def sfx():
    s = {}
    # Slide whistle up and down: the classic cartoon "zip".
    s["slide_up"] = vibrato(500, 0.55, 0.5, 0.012, 7, glide_to=1900)
    s["slide_down"] = vibrato(1900, 0.6, 0.5, 0.012, 7, glide_to=420)
    # Boing: a spring, a pitch that bends up and down while wobbling hard.
    s["boing"] = vibrato(180, 0.6, 0.6, 0.35, 11, shape="tri", glide_to=320, decay=0.25)
    # Sad trombone: wah, wah, wah, waaaah (descending, with a buzzy brassy tone).
    notes = [("D4", 0.32), ("C#4", 0.32), ("C4", 0.32), ("B3", 1.1)]
    t = 0.0
    parts = []
    for i, (n, d) in enumerate(notes):
        last = i == len(notes) - 1
        parts.append(at(t, vibrato(hz(n), d, 0.35, 0.03 if last else 0.012, 5.5, shape="saw",
                                   glide_to=hz(n) * (0.97 if last else 0.995), lowpass=1500)))
        t += d * 0.95
    s["sad_trombone"] = layer(*parts)
    # Record scratch: a fast up-down noise sweep with a tonal rasp.
    s["record_scratch"] = layer(
        noise(0.12, 0.6, decay=0.08, lowpass=900, sweep_to=4500, seed=21),
        at(0.1, noise(0.16, 0.6, decay=0.1, lowpass=4500, sweep_to=600, seed=22)),
        tone(300, 0.26, "saw", 0.12, glide_to=900, lowpass=2500, decay=0.12),
    )
    # Bonk: a hollow wood-block knock.
    s["bonk"] = layer(tone(620, 0.25, "sine", 0.6, decay=0.05, glide_to=380),
                      tone(1240, 0.1, "sine", 0.2, decay=0.02))
    # Pop: a tiny cork pop.
    s["pop"] = layer(tone(900, 0.08, "sine", 0.6, decay=0.015, glide_to=1800),
                     noise(0.03, 0.2, decay=0.006, highpass=2000, seed=23))
    # Whoosh: a breathy sweep for transitions.
    s["whoosh"] = noise(0.45, 0.5, decay=None, lowpass=300, sweep_to=5000, highpass=150, seed=24, attack=0.2)
    # Ding: a bright bell, "correct!".
    s["ding"] = layer(tone(hz("E6"), 0.9, "sine", 0.4, decay=0.3), tone(hz("E6") * 2.76, 0.4, "sine", 0.1, decay=0.1))
    # Tiptoe: two tiny plucks, for sneaky moments.
    s["tiptoe"] = layer(tone(hz("E5"), 0.09, "tri", 0.4, decay=0.03),
                        at(0.16, tone(hz("G5"), 0.09, "tri", 0.4, decay=0.03)))
    # Gasp-like "uh oh": two falling notes.
    s["uh_oh"] = layer(vibrato(hz("A5"), 0.18, 0.4, 0.01, 6, shape="tri"),
                       at(0.2, vibrato(hz("E5"), 0.32, 0.4, 0.01, 6, shape="tri", glide_to=hz("D5"))))
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, samples in sfx().items():
        A.write_wav(os.path.join(OUT, name + ".wav"), samples)
    # Background beds: the game's own themes.
    for name in ("cold_war", "subcontinent", "lounge"):
        shutil.copy(os.path.join(MUSIC, name + ".wav"), os.path.join(OUT, name + ".wav"))


if __name__ == "__main__":
    main()
