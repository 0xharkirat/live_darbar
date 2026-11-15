#!/usr/bin/env bash
# Saves the emulator screen as a PNG proof, in the skill's evidence folder.
#
#   .claude/skills/verify-live-darbar/scripts/shot.sh <feature> <step-name> [serial]
#   -> .claude/skills/verify-live-darbar/evidence/<feature>/<step-name>.png
set -euo pipefail
[[ $# -ge 2 ]] || { echo "usage: shot.sh <feature> <step-name> [serial]" >&2; exit 2; }
dir="$(cd "$(dirname "$0")/.." && pwd)/evidence/$1"
mkdir -p "$dir"
adb -s "${3:-emulator-5554}" exec-out screencap -p >"$dir/$2.png"
echo "$dir/$2.png"
