#!/usr/bin/env bash
# Read-only check: is the Live Darbar instance on the Android emulator worth
# driving? It changes nothing. Exit 0 means yes.
#
#   .claude/skills/verify-live-darbar/scripts/doctor.sh [serial]
set -uo pipefail
serial="${1:-emulator-5554}"
pkg=com.hsi.harki.live_darbar
ok=1
say() { printf '%-10s %s\n' "$1" "$2"; }

booted="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
count="$(grep -c . <<<"$booted" || true)"
say devices "$count booted: $(tr '\n' ' ' <<<"$booted")"
if [[ "$count" != 1 ]]; then say FAIL "drive exactly 1 device at a time"; ok=0; fi

if adb -s "$serial" get-state >/dev/null 2>&1; then
  say avd "$(adb -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
  say boot "$(adb -s "$serial" shell getprop sys.boot_completed | tr -d '\r')"
  say version "$(adb -s "$serial" shell dumpsys package $pkg | grep -m1 versionName | tr -d ' \r')"
  pid="$(adb -s "$serial" shell pidof $pkg | tr -d '\r')"
  say pid "${pid:-not running}"
  [[ -z "$pid" ]] && { say FAIL "app is not running"; ok=0; }
  top="$(adb -s "$serial" shell dumpsys activity activities | grep -m1 -E 'topResumedActivity|mResumedActivity' | tr -d '\r')"
  say top "${top## }"
  grep -q $pkg <<<"$top" || { say FAIL "app is not in front"; ok=0; }
else
  say FAIL "$serial is not connected"; ok=0
fi

net="$(adb -s "$serial" shell ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && echo up || echo down)"
say network "$net"
[[ "$net" == up ]] || { say FAIL "the live stream needs the network"; ok=0; }

((ok)) && echo "doctor: ok" || { echo "doctor: NOT OK"; exit 1; }
