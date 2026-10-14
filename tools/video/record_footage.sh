#!/bin/bash
# Records raw gameplay (with game sound effects, no music) for the marketing
# videos into build/footage/:
#   p-NN.mp4        portrait 1080x1920 autopilot run of mission NN (Shorts)
#   l-NN.mp4        landscape 1920x1080 autopilot run (trailer)
#   p-reck-NN.mp4   portrait "reckless" run: no dodging, no shooting (fails, gags)
# Each clip gets a .events file: "EVENT <seconds> <name>" for every notable
# moment, from the game's --log-events, so captions can be timed exactly.
# Usage: bash tools/video/record_footage.sh [clip-name ...]   (default: all)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)
out=build/footage
mkdir -p "$out"

# Movie Maker records at the project's window size and ignores --resolution,
# so each recording writes a temporary override.cfg (Godot reads it at startup
# and it overrides project.godot) with the exact window size.
trap 'rm -f override.cfg' EXIT
window() {  # w h
	printf '[display]\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n' "$1" "$2" "$1" "$2" > override.cfg
}

record() {  # name resolution level extra-flags...
	local name=$1 res=$2 level=$3; shift 3
	if [ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $name "* ]]; then return; fi
	if [ "$res" = 1080x1920 ]; then window 1080 1920; else window 1920 1080; fi
	"$GODOT" --path . --write-movie "$out/$name.avi" --fixed-fps 30 \
		-- --level="$level" --autopilot --exit-on-end --linger=1.5 --log-events --timeout=110 "$@" \
		| grep -E "^(EVENT|RESULT)" > "$out/$name.events" || true
	rm -f override.cfg
	ffmpeg -loglevel error -y -i "$out/$name.avi" -c:v libx264 -preset fast -crf 16 \
		-pix_fmt yuv420p -c:a aac -b:a 192k "$out/$name.mp4"
	rm "$out/$name.avi"
	local size; size=$(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0:s=x "$out/$name.mp4")
	[ "$size" = "$res" ] || { echo "$name recorded at $size, expected $res"; exit 1; }
	echo "$name: $(grep RESULT "$out/$name.events" || echo 'no result')"
}

ONLY="$*"
for n in $(seq 1 10); do
	id=$(printf %02d "$n")
	record "p-$id" 1080x1920 "$n"
	record "l-$id" 1920x1080 "$n"
done
for n in 1 4 9; do
	record "p-reck-$(printf %02d "$n")" 1080x1920 "$n" --reckless
done
