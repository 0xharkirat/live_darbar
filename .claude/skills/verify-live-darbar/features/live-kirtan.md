# Live Kirtan

Live Kirtan plays the live audio stream from Sri Harmandir Sahib, Amritsar. The listener starts and stops it from the home card or the mini player.

## Sub-features

- `live-play` starts the stream from the home card.
- `live-stop` stops the stream from the home card.
- `live-mini` shows the mini player once the stream plays, with its own play and stop button.
- `live-session` publishes the stream to the Android media session (notification, lock screen).

## How to get to it (user POV)

- Tap the `Play` button on the `Live Kirtan` card on home.
- Tap the stop button on the mini player at the bottom of home.
- Tapping anywhere on the `Live Kirtan` card also toggles it. This recipe does not drive that entry point.

## Driving it with orca emulator

Preconditions:

- The baseline in `README.md` holds, on a fresh launch. The `Live Kirtan` card's button reads `Play`.

- **Before.** Run `$SKILL/scripts/shot.sh live-kirtan 01-home-before-play`. The card shows a play arrow; there is no mini player.
- **Play.** In `ax`, find the `Play` node inside the bounds of the node labelled `Live Kirtan | LIVE | ...`, and tap its centre. In the proof run the node was at 817,1090 to 985,1258, so the tap was `orca emulator tap 0.834 0.489 --json`. Within 20 s that node's label becomes `Stop playback`, and a mini player titled `Live Kirtan` shows at the bottom.
- **Sound.** Run `$SKILL/scripts/session.sh PLAYING > $SKILL/evidence/live-kirtan/02-media-session.txt`. It exits 0 and shows `package=com.hsi.harki.live_darbar` with `state=PLAYING(3)`. The `flutter run` log shows `[audio] tap to sound: <n>ms (source 0, ...)`.
- **Proof of play.** Run `$SKILL/scripts/shot.sh live-kirtan 02-home-playing`.
- **Stop.** Tap the same button again. Its label returns to `Play`. The mini player stays, with a play arrow.
- **Proof of stop.** Run `$SKILL/scripts/session.sh PAUSED > $SKILL/evidence/live-kirtan/03-media-session.txt` and `$SKILL/scripts/shot.sh live-kirtan 03-home-stopped`.

## Gotchas

- The stream needs the network. With no network the app tries 3 times (about 35 s) before the button shows `Retry`. `Retry` is a failure to report. `Stop playback` alone is not proof of sound: the session must show `PLAYING(3)`.
- The live card's button is a stop, not a pause: live audio cannot resume where it left off. The session still reports `PAUSED(2)` after the stop.
- The `Play` label shows 3 times on home (live, Hukamnama, Katha). Pick the one inside the `Live Kirtan` card's bounds.
- `integration_test/live_stream_reachability_test.dart` covers `live-play` with the real player. Run it on the iOS Simulator.
