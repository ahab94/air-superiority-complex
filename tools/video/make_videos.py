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
        draw_centered(d, lines, H * (0.29 if portrait else 0.5), 150 if portrait else 140, YELLOW, W, stroke=14)
    elif style == "note":
        draw_centered(d, lines, H * 0.39, 48, (200, 220, 230), W, stroke=6)
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
        size = 84 if max(len(l) for l in lines) <= 18 else 70
        f = font(size)
        widths = [d.textlength(l, font=f) for l in lines]
        box_w, box_h = min(W - 40, max(widths) + 70), len(lines) * size * 1.15 + 44
        cy = H * 0.215
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


VIDEOS = []   # filled in below

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
