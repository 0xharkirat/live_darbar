# Live Kirtan

Live Kirtan plays the live audio stream from Sri Harmandir Sahib, Amritsar. The listener starts and stops it from the home card or the mini player.

## Sub-features

- `live-play` starts the stream from the home card.
- `live-stop` stops the stream from the home card.
- `live-mini` shows the mini player while the stream plays, with its own stop button.
- `live-session` publishes the stream to the Android media session (notification, lock screen).

## How to get to it (user POV)

- Tap the `Play` button on the `Live Kirtan` card on home.
- Tap anywhere on the `Live Kirtan` card.
- Tap the stop button on the mini player at the bottom of home.

## Driving it with orca emulator

Preconditions:

- The baseline in `README.md` holds. The `Live Kirtan` card's button reads `Play`.

- **Before.** Run `scripts/shot.sh live-kirtan 01-home-before-play`. The card shows a play arrow; no mini player.
- **Play.** In `ax`, find the `Play` node inside the `Live Kirtan | LIVE | ...` card's bounds (about 817,1090 to 985,1258), and tap its centre: `orca emulator tap 0.834 0.489 --json`. Within 20 s that node's label becomes `Stop playback`, and a mini player titled `Live Kirtan` shows at the bottom.
- **Sound.** Run `adb -s emulator-5554 shell dumpsys media_session | grep -m1 'state=PlaybackState'`. It shows `state=PLAYING(3)` for `com.hsi.harki.live_darbar`. The `flutter run` log shows `[audio] tap to sound: <n>ms (source 0, ...)`.
- **Proof of play.** Run `scripts/shot.sh live-kirtan 02-home-playing` and save the media session line as `02-media-session.txt`.
- **Stop.** Tap the same button again. Its label returns to `Play`, the media session shows `PAUSED(2)`, and the mini player leaves.
- **Proof of stop.** Run `scripts/shot.sh live-kirtan 03-home-stopped` and save the media session line as `03-media-session.txt`.

## Gotchas

- The stream needs the network. With no network the button ends on `Retry`; that is a failure to report, not a pass.
- The live card's button is a stop, not a pause: live audio cannot resume where it left off.
- The `Play` label shows 3 times on home (live, Hukamnama, Katha). Pick the one inside the `Live Kirtan` card's bounds.
- Trust the media session state for sound, not the host speakers.
