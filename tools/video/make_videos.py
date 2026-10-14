#!/usr/bin/env python3
"""Builds the marketing videos from recorded footage.

    bash tools/video/record_footage.sh            # raw gameplay -> build/footage/
    python3 tools/video/make_video_audio.py       # stingers + music beds -> build/video_audio/
    /usr/bin/python3 tools/video/make_videos.py [video-id ...]

Needs Pillow (captions) and ffmpeg. Writes build/videos/<id>.mp4 plus
docs/marketing/youtube.md (titles, descriptions, tags for uploading).

Each video is a list of segments cut from the footage (optionally sped up),
with captions burned on top. Audio = the footage's game sound effects + one of
the game's music themes + comedy stingers. Adapted from Cardboard Espionage
Action's video tools.
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FOOTAGE = os.path.join(ROOT, "build", "footage")
OUT = os.path.join(ROOT, "build", "videos")
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
VIDEO_AUDIO = os.path.join(ROOT, "build", "video_audio")


def sfx_path(name):
    """Comedy effects (build/video_audio) first, then the game's own (audio/sfx)."""
    for folder in (VIDEO_AUDIO, os.path.join(ROOT, "audio", "sfx")):
        path = os.path.join(folder, name + ".wav")
        if os.path.exists(path):
            return path
    raise FileNotFoundError(name)

PLAY = "https://ahab94.github.io/air-superiority-complex/"
PLAY_SHORT = "ahab94.github.io/air-superiority-complex"   # shown on screen
REPO = "https://github.com/ahab94/air-superiority-complex"
RELEASES = REPO + "/releases/latest"

CYAN = (181, 212, 244)      # Ace's silver-blue
YELLOW = (250, 199, 117)    # the game's gold
GREEN = (159, 225, 203)
RED = (255, 74, 58)
NAVY = (15, 26, 46)
INK = (4, 8, 16)

LINKS = f"""⭐ Open source on GitHub, a star helps a lot: {REPO}
⬇ Windows / Mac / Linux downloads: {RELEASES}"""


def description(blurb, tags):
    return f"""▶ PLAY FREE in your browser: {PLAY}

{blurb}

{LINKS}

Air Superiority Complex is a free, satirical arcade shooter in real-time 3D: parody jets, made-up countries, and ten missions told as tall tales in a bar. Cannons, lock-on missiles, flares, and two press offices that both claim victory. Optional local co-op. Made with the Godot engine; every jet, landscape and sound is made in code.

{" ".join("#" + t for t in tags)}"""


BASE_TAGS = ["air superiority complex", "indie game", "shoot em up", "free game", "browser game",
             "godot", "gamedev", "jet fighter game", "arcade shooter", "satire"]
HASHTAGS = ["AirSuperiorityComplex", "indiegame", "gamedev", "godot", "shmup"]

def frame_size(orient):
    return (1080, 1920) if orient == "portrait" else (1920, 1080)


def font(size):
    return ImageFont.truetype(FONT, size)


def draw_centered(draw, lines, y_center, size, fill, width, stroke=10, line_gap=1.12):
    f = font(size)
    heights = [size * line_gap] * len(lines)
    y = y_center - sum(heights) / 2
    for line, h in zip(lines, heights):
        w = draw.textlength(line, font=f)
        draw.text(((width - w) / 2, y), line, font=f, fill=fill, stroke_width=stroke, stroke_fill=INK)
        y += h


def caption_png(path, text, style, orient):
    """Full-frame transparent PNG with the caption placed for the format."""
    W, H = frame_size(orient)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lines = text.split("\n") if text else []
    portrait = orient == "portrait"
    if not lines:
        img.save(path)
        return
    if style == "big":
        # Punchlines go mid-screen: between the enemy formation and our jet.
        size = 150 if portrait else 140
        while size > 60 and max(d.textlength(l, font=font(size)) for l in lines) > W - 90:
            size -= 6                      # shrink to fit the frame
        draw_centered(d, lines, H * 0.5, size, YELLOW, W, stroke=14)
    elif style == "note":
        draw_centered(d, lines, H * 0.57, 48, (220, 230, 240), W, stroke=6)
    elif style == "counter":
        draw_centered(d, lines, H * 0.84, 110, GREEN, W, stroke=12)
    elif style == "cta":   # call to action with the play link, above the Shorts UI
        cy = H * (0.66 if portrait else 0.78)
        f1, f2 = font(52 if portrait else 60), font(36 if portrait else 38)
        l1, l2 = "PLAY FREE IN YOUR BROWSER", PLAY_SHORT
        w = max(d.textlength(l1, font=f1), d.textlength(l2, font=f2)) + 140
        w = min(w, W - 60)
        h = 190 if portrait else 175
        d.rounded_rectangle([(W - w) / 2, cy - h / 2, (W + w) / 2, cy + h / 2], 30, fill=(255, 216, 74, 245))
        # a drawn "play" triangle, since the font has no symbol for it
        tx = (W - d.textlength(l1, font=f1)) / 2 - 10
        d.polygon([(tx - 46, cy - 62), (tx - 46, cy - 18), (tx - 8, cy - 40)], fill=INK)
        d.text(((W - d.textlength(l1, font=f1)) / 2 + 12, cy - 75), l1, font=f1, fill=INK)
        d.text(((W - d.textlength(l2, font=f2)) / 2, cy + 18), l2, font=f2, fill=(20, 40, 60))
    elif style == "low":   # landscape lower-third
        size = 76
        f = font(size)
        widths = [d.textlength(l, font=f) for l in lines]
        box_w, box_h = max(widths) + 80, len(lines) * size * 1.15 + 40
        y0 = H - box_h - 120
        d.rounded_rectangle([(W - box_w) / 2, y0, (W + box_w) / 2, y0 + box_h], 28, fill=(3, 10, 18, 190))
        draw_centered(d, lines, y0 + box_h / 2, size, (255, 255, 255), W, stroke=0)
    else:  # hook: the top band of a Short, where the platform UI doesn't cover it
        size = 76 if max(len(l) for l in lines) <= 18 else 62
        f = font(size)
        widths = [d.textlength(l, font=f) for l in lines]
        box_w, box_h = min(W - 40, max(widths) + 70), len(lines) * size * 1.15 + 44
        # Over the HUD strip at the very top: in this game the enemies fly
        # just below it, so captions must not sit on the formation.
        cy = H * 0.115
        d.rounded_rectangle([(W - box_w) / 2, cy - box_h / 2, (W + box_w) / 2, cy + box_h / 2], 34,
                            fill=(255, 255, 255, 235))
        draw_centered(d, lines, cy, size, INK, W, stroke=0)
    img.save(path)


def draw_jet(d, cx, cy, s, col=(181, 212, 244)):
    """Ace's jet as a flat emblem (the game's 2D silhouette, scaled)."""
    half = [(0, -22), (4, -12), (6, -12), (6, -4), (17, 6), (17, 10), (6, 8), (6, 14), (10, 18), (10, 21), (4, 19), (0, 20)]
    pts = [(cx + x * s, cy + y * s) for x, y in half] + [(cx - x * s, cy + y * s) for x, y in reversed(half[1:-1])]
    d.polygon(pts, fill=col, outline=INK, width=max(3, int(s // 2)))
    for k in (-3.5, 3.5):   # afterburners
        d.polygon([(cx + (k - 2.5) * s, cy + 20 * s), (cx + (k + 2.5) * s, cy + 20 * s), (cx + k * s, cy + 34 * s)], fill=(239, 159, 39))


def grid(d, W, H, step):
    for x in range(0, W, step):
        d.line([x, 0, x, H], fill=(28, 44, 72), width=2)
    for y in range(0, H, step):
        d.line([0, y, W, y], fill=(28, 44, 72), width=2)


def card_png(path, orient, title_lines, kind):
    W, H = frame_size(orient)
    img = Image.new("RGB", (W, H), NAVY)
    d = ImageDraw.Draw(img)
    grid(d, W, H, 90)
    portrait = orient == "portrait"
    if kind == "intro":
        draw_jet(d, W // 2, int(H * (0.34 if portrait else 0.3)), 9 if portrait else 7)
        draw_centered(d, title_lines, H * (0.6 if portrait else 0.7), 116 if portrait else 106, YELLOW, W, stroke=12)
    else:  # outro: title + call to action
        draw_jet(d, W // 2, int(H * (0.22 if portrait else 0.2)), 7 if portrait else 5)
        draw_centered(d, ["AIR SUPERIORITY", "COMPLEX"] if portrait else ["AIR SUPERIORITY COMPLEX"],
                      H * (0.42 if portrait else 0.44), 100 if portrait else 92, (255, 255, 255), W, stroke=10)
        draw_centered(d, ["PLAY FREE", "IN YOUR BROWSER"] if portrait else ["PLAY FREE IN YOUR BROWSER"],
                      H * (0.58 if portrait else 0.62), 84 if portrait else 78, YELLOW, W, stroke=10)
        draw_centered(d, [PLAY_SHORT], H * (0.69 if portrait else 0.75), 44 if portrait else 44, (255, 255, 255), W, stroke=6)
        draw_centered(d, ["free & open source on GitHub"],
                      H * (0.76 if portrait else 0.85), 44 if portrait else 40, (170, 190, 215), W, stroke=6)
    img.save(path)


def thumbnail_png(path, frame_src=None, t=0.0, lines=("WHO WON?", "BOTH."), color=YELLOW):
    """Thumbnail (1280x720): a dramatic frame from the footage with big text."""
    W, H = 1280, 720
    if frame_src:
        tmp = path + ".frame.png"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", f"{t:.2f}", "-i", os.path.join(FOOTAGE, frame_src + ".mp4"),
                        "-frames:v", "1", "-vf", f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H}", tmp], check=True)
        img = Image.open(tmp).convert("RGB")
        os.remove(tmp)
    else:
        img = Image.new("RGB", (W, H), NAVY)
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, W, H], fill=(0, 0, 0, 70))
    draw_centered(d, list(lines), H * 0.32, 150, color, W, stroke=14)
    img.save(path)


# --- The videos --------------------------------------------------------------
# Segment times are in seconds of the source clip (from its .events file);
# caption and sfx times are in seconds of the finished video, counted from
# the first gameplay frame (after any intro card).

T1 = ["air superiority complex", "game trailer", "indie game trailer"]
SH = ["shorts"]

VIDEOS = [
    {
        "id": "01-trailer", "orient": "landscape", "music": "cold_war",
        "intro": ("EVERY DOGFIGHT\nIS A TALL TALE.", 2.6),
        "segments": [
            ("l-01", 1.4, 6.0, 1.2), ("l-01", 21.8, 25.2, 1.0), ("l-02", 11.0, 15.0, 1.0),
            ("l-03", 15.5, 21.5, 1.3), ("l-04", 18.5, 21.0, 1.0), ("l-05", 27.5, 32.5, 1.0),
            ("l-06", 3.5, 7.5, 1.0), ("l-07", 23.0, 27.0, 1.2), ("l-08", 10.5, 13.0, 1.0),
            ("l-09", 16.0, 21.0, 1.3), ("l-10", 11.0, 16.0, 1.0),
        ],
        "captions": [
            (0.2, 3.8, "Parody jets. Made-up countries.", "low"),
            (3.9, 7.2, "Lock on. Let go.", "low"),
            (7.3, 11.2, "No guns. One camera.", "low"),
            (11.3, 15.8, "Don't shoot across the river.", "low"),
            (15.9, 18.3, "Outrun the missiles.", "low"),
            (18.4, 23.3, "Bring down the Tuba Grizzly.", "low"),
            (23.4, 27.3, "Five in a minute*", "low"),
            (27.4, 30.6, "Monsoon dogfights.", "low"),
            (30.7, 33.1, "Night. Heat-seekers. Flares.", "low"),
            (33.2, 37.0, "Mountain turbulence.", "low"),
            (37.1, 42.0, "Then switch sides.", "low"),
        ],
        "sfx": [(-2.4, "pop"), (-0.5, "slide_up"), (24.6, "kaching", 0.8), (38.3, "stamp", 0.8)],
        "cut_whoosh": True, "caption_pop": False, "outro": 4.5,
        "thumb": ("l-10", 12.6, ("WHO WON?", "BOTH.")),
        "title": "Air Superiority Complex: every dogfight is a tall tale (free browser game trailer)",
        "blurb": "Parody jets, made-up countries, ten missions told as tall tales in a bar. Cannons, lock-on missiles, flares and two press offices that both claim victory.",
        "tags": BASE_TAGS + T1,
    },
    {
        "id": "01b-trailer-short", "orient": "portrait", "music": "cold_war",
        "intro": ("EVERY\nDOGFIGHT IS\nA TALL TALE.", 2.0),
        "segments": [
            ("p-01", 21.8, 25.2, 1.0), ("p-02", 11.0, 14.5, 1.0), ("p-04", 18.5, 21.0, 1.0),
            ("p-05", 27.5, 32.5, 1.1), ("p-06", 3.5, 7.0, 1.0), ("p-08", 10.5, 13.0, 1.0),
            ("p-09", 16.0, 20.0, 1.3), ("p-10", 11.0, 15.5, 1.0),
        ],
        "captions": [
            (0.1, 3.3, "Lock on. Let go.", "hook"),
            (3.4, 6.8, "No guns.\nOne camera.", "hook"),
            (6.9, 9.3, "Outrun the missiles", "hook"),
            (9.4, 13.8, "Boss: the\nTUBA GRIZZLY", "hook"),
            (13.9, 17.3, "Five in a minute*", "hook"),
            (17.4, 19.8, "Night. Flares.", "hook"),
            (19.9, 22.8, "Mountains", "hook"),
            (22.9, 27.3, "Then switch sides.", "hook"),
        ],
        "sfx": [(-1.8, "pop"), (-0.4, "slide_up"), (15.4, "kaching", 0.8), (24.2, "stamp", 0.8)],
        "cut_whoosh": True, "outro": 3.5,
        "title": "Every dogfight is a tall tale ✈️ #shorts",
        "blurb": "A free satirical jet shooter: parody jets, made-up countries, ten missions. Play it in your browser.",
        "tags": BASE_TAGS + SH + ["game trailer"],
    },
    {
        "id": "02-both-sides-win", "orient": "portrait", "music": "subcontinent",
        "segments": [("p-10", 1.5, 14.5, 1.1), ("p-06", 3.5, 8.0, 1.0)],
        "captions": [
            (0.0, 3.0, "I made a game where\nBOTH SIDES WIN", "hook"),
            (3.0, 7.0, "Missiles only.\nNobody crosses the line.", "hook"),
            (7.0, 9.7, "Lock four. Let go.", "hook"),
            (9.7, 11.8, "...then I switched sides", "hook"),
            (11.8, 16.3, "Kills: 8\nClaimed: 16", "hook"),
        ],
        "sfx": [(9.8, "stamp"), (10.0, "kaching", 0.8), (13.75, "kaching"), (13.9, "boing", 0.6)],
        "cut_whoosh": True,
        "title": "I made a game where BOTH SIDES always win ✈️ #shorts",
        "blurb": "Two neighbours, one Line nobody crosses, and two Ministries of Claims that both announce victory. It's a free browser game.",
        "tags": BASE_TAGS + SH + ["i made a game", "satire game"],
    },
    {
        "id": "03-flares", "orient": "portrait", "music": "subcontinent",
        "segments": [("p-08", 9.5, 20.5, 1.0), ("p-04", 8.0, 15.8, 1.0)],
        "captions": [
            (0.0, 2.4, "Heat-seeker\nincoming...", "hook"),
            (2.4, 3.8, "FLARES!", "big"),
            (3.8, 8.6, "Works every time*", "hook"),
            (7.6, 8.6, "*mostly", "note"),
            (9.9, 11.0, "AGAIN!", "big"),
            (11.0, 18.8, "Even in a spy jet\nwith NO GUNS", "hook"),
        ],
        "sfx": [(1.3, "uh_oh", 0.8), (2.4, "slide_up", 0.7), (9.9, "slide_up", 0.7)],
        "cut_whoosh": True,
        "title": "Heat-seeker vs flares 🔥 #shorts",
        "blurb": "Every missile in this game can be fooled by flares. Mostly. Free to play in your browser.",
        "tags": BASE_TAGS + SH + ["flares", "missile dodge"],
    },
    {
        "id": "04-spy-no-guns", "orient": "portrait", "music": "cold_war",
        "segments": [("p-02", 7.5, 23.0, 1.2)],
        "captions": [
            (0.0, 3.0, "A spy plane\nwith NO GUNS", "hook"),
            (3.0, 4.6, "Say cheese.", "big"),
            (4.6, 8.5, "Missile sites below.\nFlares only.", "hook"),
            (8.5, 11.2, "Fly over the target...", "hook"),
            (11.2, 12.9, "CLICK.", "big"),
        ],
        "sfx": [(3.9, "pop"), (12.3, "ding")],
        "cut_whoosh": False,
        "title": "Spy plane. No guns. One camera. 📸 #shorts",
        "blurb": "In this mission your jet has no weapons: dodge the missile sites and photograph the targets. Free browser game.",
        "tags": BASE_TAGS + SH + ["spy plane"],
    },
    {
        "id": "05-outrun-missiles", "orient": "portrait", "music": "cold_war",
        "segments": [("p-04", 8.5, 20.5, 1.2), ("p-reck-04", 9.5, 13.5, 1.0)],
        "captions": [
            (0.0, 3.2, "This jet has no guns.\nIts plan: go faster.", "hook"),
            (3.2, 10.0, "Missiles can't catch\nwhat they can't reach", "hook"),
            (10.0, 12.2, "Usually.", "big"),
        ],
        "sfx": [(11.9, "record_scratch"), (12.3, "sad_trombone", 0.9)],
        "cut_whoosh": True,
        "title": "Trying to outrun missiles in a jet with no guns 🚀 #shorts",
        "blurb": "The Blackbirb's only defence is speed. Mostly works. Free browser game.",
        "tags": BASE_TAGS + SH + ["fail", "missile dodge"],
    },
    {
        "id": "06-boss", "orient": "portrait", "music": "cold_war",
        "segments": [("p-05", 25.0, 40.0, 1.2)],
        "captions": [
            (0.0, 3.0, "BOSS FIGHT:\nthe Tuba Grizzly", "hook"),
            (3.0, 7.0, "4 missiles.\nBarely a dent.", "hook"),
            (7.0, 11.4, "Cannons it is.", "hook"),
            (11.5, 12.5, "DOWN!", "big"),
        ],
        "sfx": [(2.6, "uh_oh", 0.7), (11.5, "slide_down", 0.6)],
        "title": "Boss fight: the TUBA GRIZZLY ✈️ #shorts",
        "blurb": "A four-prop bomber with tail guns and feelings. Free browser game.",
        "tags": BASE_TAGS + SH + ["boss fight"],
    },
    {
        "id": "07-coffee-two-sugars", "orient": "portrait", "music": "subcontinent",
        "segments": [("p-reck-09", 6.5, 24.5, 1.25)],
        "captions": [
            (0.0, 2.1, "Shot down over\nthe border?", "hook"),
            (2.1, 5.8, "Steer your parachute\nHOME...", "hook"),
            (5.9, 9.8, "...or stay for coffee.", "hook"),
            (9.9, 13.6, "Me, every time:", "hook"),
            (13.6, 14.4, "Two sugars.", "big"),
        ],
        "sfx": [(2.08, "record_scratch"), (5.86, "tea"), (9.86, "bonk"), (13.64, "tea")],
        "cut_whoosh": False,
        "title": "Shot down? Steer home... or stay for coffee ☕ #shorts",
        "blurb": "Land your parachute on the wrong side and the neighbours put the kettle on. Free browser game.",
        "tags": BASE_TAGS + SH + ["funny game", "parachute"],
    },
    {
        "id": "08-sanctuary", "orient": "portrait", "music": "cold_war",
        "segments": [("p-03", 8.0, 22.0, 1.3)],
        "captions": [
            (0.0, 3.4, "You may NOT shoot\nacross the river.", "hook"),
            (3.4, 6.0, "They know.", "big"),
            (6.0, 10.8, "So they wait...\nthen dive out.", "hook"),
        ],
        "sfx": [(3.4, "uh_oh", 0.8)],
        "title": "You're not allowed to shoot across the river 🌊 #shorts",
        "blurb": "The enemy hides where you can't touch them. Catch them on the way out. Free browser game.",
        "tags": BASE_TAGS + SH,
    },
    {
        "id": "09-five-in-a-minute", "orient": "portrait", "music": "subcontinent",
        "segments": [("p-06", 1.3, 21.0, 1.3)],
        "captions": [
            (0.0, 3.0, "Five kills\nin a minute?", "hook"),
            (3.2, 5.0, "FIVE IN A MINUTE*", "big"),
            (4.2, 5.0, "*figures disputed", "note"),
            (5.0, 10.0, "Dodge the flak rings", "hook"),
            (10.0, 14.6, "The ministry\nis counting...", "hook"),
            (14.7, 15.2, "Claimed: lots.", "big"),
        ],
        "sfx": [(3.19, "kaching"), (14.73, "kaching")],
        "title": "Five kills in a minute* (*figures disputed) #shorts",
        "blurb": "The Ministry of Claims counts your kills. Generously. Free browser game.",
        "tags": BASE_TAGS + SH + ["satire game"],
    },
    {
        "id": "10-tiny-jet-monsoon", "orient": "portrait", "music": "subcontinent",
        "segments": [("p-07", 1.3, 27.0, 1.5)],
        "captions": [
            (0.0, 3.2, "A fighter jet the size\nof a COFFEE TABLE", "hook"),
            (3.2, 6.5, "...in a MONSOON", "hook"),
            (6.5, 12.0, "Tiny. Angry.\nHard to hit.", "hook"),
            (12.0, 17.1, "Wind: also angry.", "hook"),
        ],
        "sfx": [(3.2, "boing", 0.7)],
        "title": "A fighter jet the size of a coffee table... in a monsoon 🌧️ #shorts",
        "blurb": "The Fallin' Midge: so small enemies check their windscreens for bugs. Free browser game.",
        "tags": BASE_TAGS + SH,
    },
    {
        "id": "11-i-made-a-game", "orient": "portrait", "music": "cold_war",
        "segments": [
            ("p-01", 1.5, 6.0, 1.3), ("p-02", 11.0, 14.5, 1.0), ("p-04", 18.5, 21.0, 1.0),
            ("p-05", 27.5, 31.5, 1.2), ("p-09", 16.0, 20.0, 1.3), ("p-10", 11.5, 15.5, 1.0),
        ],
        "captions": [
            (0.0, 3.5, "I made a jet game\nwhere every mission\nis a tall tale", "hook"),
            (3.5, 7.0, "Spy planes", "hook"),
            (7.0, 9.5, "Missiles", "hook"),
            (9.5, 12.8, "Bosses", "hook"),
            (12.8, 15.9, "Mountains", "hook"),
            (15.9, 19.9, "Free in your browser", "hook"),
        ],
        "sfx": [(15.9, "ding")],
        "cut_whoosh": True,
        "title": "I made a jet game where every mission is a tall tale ✈️ #shorts",
        "blurb": "Ten missions, parody jets, made-up countries, all made in code with Godot. Should I make ten more?",
        "tags": BASE_TAGS + SH + ["i made a game", "devlog"],
    },
]


# --- Assembly --------------------------------------------------------------------

def run(cmd):
    subprocess.run(cmd, check=True)


def atempo_chain(speed):
    # atempo accepts 0.5..2.0 per stage, so chain stages for bigger changes.
    parts, s = [], speed
    while s > 2.0:
        parts.append("atempo=2.0")
        s /= 2.0
    parts.append(f"atempo={s:.4f}")
    return ",".join(parts)


def cut(src, start, end, speed, path, W, H, keep_audio):
    vf = f"setpts=PTS/{speed},scale={W}:{H},fps=30"
    cmd = ["ffmpeg", "-loglevel", "error", "-y", "-ss", str(start), "-to", str(end),
           "-i", os.path.join(FOOTAGE, src + ".mp4"), "-vf", vf]
    if keep_audio:
        cmd += ["-af", atempo_chain(speed) + ",aresample=48000", "-c:a", "aac", "-b:a", "192k", "-ac", "2"]
    else:
        cmd += ["-an"]
    cmd += ["-c:v", "libx264", "-preset", "fast", "-crf", "16", "-pix_fmt", "yuv420p", path]
    run(cmd)


def still(png, seconds, path, keep_audio):
    cmd = ["ffmpeg", "-loglevel", "error", "-y", "-loop", "1", "-t", str(seconds), "-i", png]
    if keep_audio:
        cmd += ["-f", "lavfi", "-t", str(seconds), "-i", "anullsrc=r=48000:cl=stereo",
                "-c:a", "aac", "-b:a", "192k", "-shortest"]
    cmd += ["-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-preset", "fast", "-crf", "16", path]
    run(cmd)


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True, check=True).stdout
    return float(out.strip())


def build(v, tmp):
    W, H = frame_size(v["orient"])
    clip_audio = True   # always keep the footage's game sound effects
    parts = []
    if "intro" in v:
        text, secs = v["intro"]
        png = os.path.join(tmp, "intro.png")
        card_png(png, v["orient"], text.split("\n"), "intro")
        parts.append(os.path.join(tmp, "intro.mp4"))
        still(png, secs, parts[-1], clip_audio)
    for i, (src, a, b, speed) in enumerate(v["segments"]):
        parts.append(os.path.join(tmp, f"seg{i}.mp4"))
        cut(src, a, b, speed, parts[-1], W, H, clip_audio)
    if v.get("outro"):
        png = os.path.join(tmp, "outro.png")
        card_png(png, v["orient"], [], "outro")
        parts.append(os.path.join(tmp, "outro.mp4"))
        still(png, v["outro"], parts[-1], clip_audio)

    listing = os.path.join(tmp, "list.txt")
    with open(listing, "w") as f:
        f.writelines(f"file '{p}'\n" for p in parts)
    joined = os.path.join(tmp, "joined.mp4")
    run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", joined])
    total = duration(joined)
    offset = v["intro"][1] if "intro" in v else 0.0   # captions are timed from the first gameplay frame

    # Captions: one transparent full-frame PNG each, shown over its time window.
    # Every video ends with the play link on screen: links in Shorts
    # descriptions aren't clickable, so viewers need to see the address.
    gameplay_end = total - offset - (v.get("outro") or 0)
    captions = list(v["captions"])
    if not v.get("outro"):
        captions.append((max(0.0, gameplay_end - 3.0), gameplay_end, "cta", "cta"))
    inputs, filters, last = [], [], "[0:v]"
    for i, (t0, t1, text, style) in enumerate(captions):
        png = os.path.join(tmp, f"cap{i}.png")
        caption_png(png, text, style, v["orient"])
        # Loop the still image for the whole video: a single-frame input ends
        # immediately, so a caption that starts after an intro card would never show.
        inputs += ["-loop", "1", "-t", f"{total:.2f}", "-i", png]
        filters.append(f"{last}[{i + 1}:v]overlay=0:0:enable='between(t,{t0 + offset:.2f},{t1 + offset:.2f})'[v{i}]")
        last = f"[v{i}]"
    n_caps = len(captions)

    # Audio: the clip's game sound effects (footage is recorded without game
    # music), a playful music bed, comedy stingers from the spec, a soft pop
    # on every caption and a whoosh on every cut.
    cues = [(t + offset, name, vol) for t, name, vol in
            [(c[0], c[1], c[2] if len(c) > 2 else 1.0) for c in v.get("sfx", [])]]
    if v.get("caption_pop", True):
        cues += [(t0 + offset, "pop", 0.45) for t0, _, text, _ in v["captions"] if text]
    if v.get("cut_whoosh"):
        t = offset
        for _, a, b, speed in v["segments"][:-1]:
            t += (b - a) / speed
            cues.append((t - 0.15, "whoosh", 0.5))
    base = n_caps + 1
    audio_inputs = ["-stream_loop", "-1", "-i", os.path.join(VIDEO_AUDIO, v.get("music", "cold_war") + ".wav")]
    mix = ["[0:a]volume=1.0[g]", f"[{base}:a]volume={v.get('music_volume', 0.5)}[m]"]
    labels = ["[g]", "[m]"]
    for j, (t, name, vol) in enumerate(cues):
        audio_inputs += ["-i", sfx_path(name)]
        ms = max(0, int(t * 1000))
        mix.append(f"[{base + 1 + j}:a]adelay={ms}|{ms},volume={vol * 1.2:.2f}[s{j}]")
        labels.append(f"[s{j}]")
    mix.append(f"{''.join(labels)}amix=inputs={len(labels)}:normalize=0:duration=first,atrim=0:{total:.2f},"
               f"loudnorm=I=-14:TP=-1.5:LRA=11,afade=t=in:d=0.2,afade=t=out:st={total - 0.8:.2f}:d=0.8,"
               f"aresample=48000[a]")
    audio_filter = ";".join(mix)

    graph = ";".join(filters + [audio_filter]) if filters else audio_filter
    vmap = last if filters else "0:v"
    out = os.path.join(OUT, v["id"] + ".mp4")
    run(["ffmpeg", "-loglevel", "error", "-y", "-i", joined, *inputs, *audio_inputs,
         "-filter_complex", graph, "-map", vmap, "-map", "[a]",
         "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30",
         "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-movflags", "+faststart", "-t", f"{total:.2f}", out])
    print(f"{v['id']}: {total:.1f}s -> {os.path.relpath(out, ROOT)}")
    return total


def write_metadata(lengths):
    path = os.path.join(ROOT, "docs", "marketing", "youtube.md")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = ["# YouTube uploads", "",
             "Generated by `tools/video/make_videos.py`. Audience: **No, it's not made for kids** (family-friendly, all ages).",
             "Upload as **Private** first, then publish after review.", ""]
    for v in VIDEOS:
        lines += [f"## {v['id']} ({'Short' if v['orient'] == 'portrait' else 'video'}, {lengths.get(v['id'], 0):.0f}s)", "",
                  f"**Title:** {v['title']}", "", "**Description:**", "", "```",
                  description(v["blurb"], HASHTAGS),
                  "```", "", f"**Tags:** {', '.join(v['tags'])}", ""]
    with open(path, "w") as f:
        f.write("\n".join(lines))
    with open(os.path.join(OUT, "metadata.json"), "w") as f:
        json.dump([{"id": v["id"], "file": v["id"] + ".mp4", "title": v["title"],
                    "description": description(v["blurb"], HASHTAGS),
                    "tags": v["tags"], "short": v["orient"] == "portrait"} for v in VIDEOS], f, indent=2)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    os.makedirs(OUT, exist_ok=True)
    wanted = set(sys.argv[1:])
    lengths = {}
    for v in VIDEOS:
        if wanted and v["id"] not in wanted and v["id"].split("-")[0] not in wanted:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            lengths[v["id"]] = build(v, tmp)
    for v in VIDEOS:
        if "thumb" in v and (not wanted or v["id"] in wanted):
            src, t, lines = v["thumb"]
            thumbnail_png(os.path.join(OUT, v["id"] + "-thumbnail.png"), src, t, lines)
    if not wanted:
        write_metadata(lengths)


if __name__ == "__main__":
    main()
