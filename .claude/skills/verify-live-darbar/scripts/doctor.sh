#!/usr/bin/env bash
# Read-only check: is the Live Darbar instance on the Android emulator worth
# driving? It changes nothing. Exit 0 means yes.
#
#   .claude/skills/verify-live-darbar/scripts/doctor.sh [serial]
#
# The serial defaults to the only booted device.
set -uo pipefail
pkg=com.hsi.harki.live_darbar
want_avd=live_darbar_api36
want_size=1080x2400
repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
want_version="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' "$repo/pubspec.yaml")"
ok=1
say() { printf '%-10s %s\n' "$1" "$2"; }
bad() { say FAIL "$1"; ok=0; }

booted="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
count="$(grep -c . <<<"$booted" || true)"
say devices "$count booted: $(tr '\n' ' ' <<<"$booted")"
[[ "$count" == 1 ]] || bad "drive exactly 1 device at a time"
serial="${1:-$(head -1 <<<"$booted")}"
say serial "${serial:-none}"

if [[ -n "$serial" ]] && adb -s "$serial" get-state >/dev/null 2>&1; then
  sh() { adb -s "$serial" shell "$@" | tr -d '\r'; }
  avd="$(adb -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
  say avd "$avd"
  [[ "$avd" == "$want_avd" ]] || bad "the AVD is not $want_avd"
  boot="$(sh getprop sys.boot_completed)"
  say boot "$boot"
  [[ "$boot" == 1 ]] || bad "the device has not finished booting"
  size="$(sh wm size | awk '{print $NF}')"
  say size "$size"
  [[ "$size" == "$want_size" ]] || bad "the recipes assume a $want_size screen"
  version="$(sh dumpsys package $pkg | sed -n 's/.*versionName=//p' | head -1)"
  say version "${version:-not installed}"
  [[ "$version" == "$want_version" ]] || bad "the installed build is not $want_version from pubspec.yaml"
  pid="$(sh pidof $pkg)"
  say pid "${pid:-not running}"
  [[ -n "$pid" ]] || bad "the app is not running"
  top="$(sh dumpsys activity activities | grep -m1 -E 'topResumedActivity|mResumedActivity')"
  say top "$(sed 's/^ *//' <<<"$top")"
  grep -q $pkg <<<"$top" || bad "the app is not in front"
  if sh ping -c 1 -W 3 live.sgpc.net >/dev/null 2>&1; then say network up
  else bad "the device cannot reach live.sgpc.net, the live stream host"; fi
else
  bad "no connected device"
fi

if ((ok)); then echo "doctor: ok"; else echo "doctor: NOT OK"; exit 1; fi
