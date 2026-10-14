#!/bin/bash
# Done when: the project imports, the rules tests pass, the autopilot beats
# every mission in the simulation, and the real game beats them too.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
check() {  # script, success marker
	local out
	out=$("$GODOT" --headless --path . --script "$1" 2>&1) || { echo "$out"; exit 1; }
	if echo "$out" | grep -q "SCRIPT ERROR" || ! echo "$out" | grep -q "$2"; then echo "$out"; echo "failed: $1"; exit 1; fi
	echo "$out" | grep -E "^mission" || true
}
check res://tests/smoke_test.gd "SMOKE OK"
check res://tests/sim_test.gd "SIM OK"
bash checks/autoplay.sh | tail -1
echo "air-superiority-complex: all good"
