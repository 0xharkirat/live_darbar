#!/usr/bin/env bash
# Saves the emulator screen as a PNG proof, 1200 px tall, in the skill's
# evidence folder. It writes nothing when the capture fails.
#
#   .claude/skills/verify-live-darbar/scripts/shot.sh <feature> <NN-step> [serial]
#   -> .claude/skills/verify-live-darbar/evidence/<feature>/<NN-step>.png
set -euo pipefail
[[ $# -ge 2 ]] || { echo "usage: shot.sh <feature> <NN-step> [serial]" >&2; exit 2; }
for name in "$1" "$2"; do
  [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
    { echo "shot.sh: '$name' must be lowercase letters, digits and dashes" >&2; exit 2; }
done
serial="${3:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
dir="$(cd "$(dirname "$0")/.." && pwd)/evidence/$1"
mkdir -p "$dir"
tmp="$dir/.shot-$$.png"
trap 'rm -f "$tmp"' EXIT
adb -s "$serial" exec-out screencap -p >"$tmp"
[[ "$(head -c 4 "$tmp" | tail -c 3)" == PNG ]] ||
  { echo "shot.sh: the capture is not a PNG" >&2; exit 1; }
sips -Z 1200 "$tmp" >/dev/null
mv "$tmp" "$dir/$2.png"
echo "$dir/$2.png"
