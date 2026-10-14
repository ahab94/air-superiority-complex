#!/bin/bash
# The real game (window, input path, rendering) beats every mission on
# autopilot, solo and in co-op. Runs faster than real time.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)
N=$(grep -c '"id":' scripts/levels.gd)
for ((n = 1; n <= N; n++)); do
	for players in 1 2; do
		full=$("$GODOT" --headless --fixed-fps 60 --path . -- --level=$n --players=$players --autopilot --exit-on-end --timeout=600 2>&1 || true)
		out=$(echo "$full" | grep RESULT || true)
		echo "$out"
		echo "$out" | grep -q "RESULT win" || { echo "autoplay failed: mission $n, $players player(s)"; exit 1; }
		# Any runtime script error during a mission fails the check too.
		if echo "$full" | grep -q "SCRIPT ERROR"; then
			echo "$full" | grep "SCRIPT ERROR" | sort | uniq -c | head
			echo "script errors: mission $n, $players player(s)"; exit 1
		fi
	done
done
echo "autoplay: all missions won"
