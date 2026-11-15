# Daily recordings

Home offers 2 recordings for today under `TODAY`: the Hukamnama as read at Sri Harmandir Sahib, and the Hukamnama Katha that explains its meaning. Each plays from its own card and shows in the mini player.

## Sub-features

- `rec-hukamnama` plays today's Hukamnama recording.
- `rec-katha` plays today's Hukamnama Katha.
- `rec-pause` pauses and resumes a recording where it left off.
- `rec-switch` moves from one source to another, so only 1 plays at a time.

## How to get to it (user POV)

- Tap the `Play` button on the `Hukamnama` or `Hukamnama Katha` card under `TODAY` on home.
- Tap anywhere on either card.
- Open the player from the mini player and pick `Live`, `Hukamnama`, or `Katha` in the source switch.

## Driving it with orca emulator

Preconditions:

- The baseline in `README.md` holds.

- **Hukamnama.** Tap the `Play` node inside the `Hukamnama | Hukamnama | Today’s recording` card (about 380,1728 to 495,1844): `orca emulator tap 0.405 0.745 --json`. Its label becomes `Pause`; the media session shows `PLAYING(3)`.
- **Pause.** Tap it again. The label becomes `Play`; the media session shows `PAUSED(2)`. Tap again: playback resumes at the same position, not at 0.
- **Katha.** Tap the `Play` node inside the `Hukamnama Katha` card (about 886,1728 to 1001,1844): `orca emulator tap 0.874 0.745 --json`. The Katha button reads `Pause`, and the Hukamnama button reads `Play` again.
- **Proof.** Run `scripts/shot.sh daily-recordings 01-hukamnama-playing`, `02-katha-playing`, and save each media session line.
- **Stop.** Pause the Katha before you leave the recipe.

## Gotchas

- The recordings are SGPC's files for today's date in Amritsar. Before they are out, a card shows an earlier day; read its subtitle.
- Resume position lives in the app. Clearing app data resets it, so do not clear data mid-recipe.
- The card positions above are for the English layout on 15 Nov 2026. Re-read `ax` bounds on each run.
