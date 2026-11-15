#!/usr/bin/env bash
# Prints the Android media session state of Live Darbar, and only of Live
# Darbar: its package line and its PlaybackState line. With an expected state,
# it reads again once a second until that state shows, for at most 20 s.
#
#   .claude/skills/verify-live-darbar/scripts/session.sh [PLAYING|PAUSED|STOPPED] [serial]
#
# Exit 0 when the state matches (or no state was asked for), 1 when it does not.
set -uo pipefail
want="${1:-}"
serial="${2:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
pkg=com.hsi.harki.live_darbar
read_state() {
  adb -s "$serial" shell dumpsys media_session | tr -d '\r' |
    awk -v p="package=$pkg" 'index($0, p) {f=1; print; next}
      f && /state=PlaybackState/ {print; exit}'
}
for _ in $(seq 1 20); do
  out="$(read_state)"
  if [[ -z "$want" ]] || grep -q "state=$want(" <<<"$out"; then
    sed 's/^ *//' <<<"${out:-no media session for $pkg}"
    exit 0
  fi
  sleep 1
done
sed 's/^ *//' <<<"${out:-no media session for $pkg}"
echo "session.sh: the state is not $want after 20 s" >&2
exit 1
