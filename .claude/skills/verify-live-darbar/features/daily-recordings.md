# Daily recordings

Home offers 2 recordings for today under `TODAY`: the Hukamnama as read at Sri Harmandir Sahib, and the Hukamnama Katha that explains its meaning. Each plays from its own card and shows in the mini player.

## Sub-features

- `rec-hukamnama` plays today's Hukamnama recording.
- `rec-katha` plays today's Hukamnama Katha.
- `rec-pause` pauses and resumes a recording where it left off.
- `rec-switch` moves from one source to another, so only 1 plays at a time.

## How to get to it (user POV)

- Tap the `Play` button on the `Hukamnama` or `Hukamnama Katha` card under `TODAY` on home.
- Open the player from the mini player and pick `Live`, `Hukamnama`, or `Katha` in the source switch. This recipe does not drive that entry point yet.

## Driving it with orca emulator

Preconditions:

- The baseline in `README.md` holds.

- **Hukamnama.** In `ax`, find the `Play` node inside the bounds of the node labelled `Hukamnama | Hukamnama | Today’s recording`, and tap its centre. Its label becomes `Pause`. Run `$SKILL/scripts/session.sh PLAYING > $SKILL/evidence/daily-recordings/01-media-session.txt`; it exits 0.
- **Proof.** Run `$SKILL/scripts/shot.sh daily-recordings 01-hukamnama-playing`.
- **Pause.** Wait at least 10 s, then tap the button again. The label becomes `Play`. Run `$SKILL/scripts/session.sh PAUSED` and note its `position=` value.
- **Resume.** Tap the button again. Run `$SKILL/scripts/session.sh PLAYING`. Its `position=` is at or after the paused position, not 0.
- **Katha.** Find the `Play` node inside the `Hukamnama Katha | ...` card and tap its centre. The Katha button reads `Pause`, and the Hukamnama button reads `Play` again. Run `$SKILL/scripts/session.sh PLAYING > $SKILL/evidence/daily-recordings/02-media-session.txt` and `$SKILL/scripts/shot.sh daily-recordings 02-katha-playing`.
- **Stop.** Pause the Katha before you leave the recipe.

## Gotchas

- The recordings are SGPC's files for today's date in Amritsar. Before they are out, a card shows an earlier day; read its subtitle.
- The app keeps the resume position. Clearing app data resets it, so do not clear data mid-recipe.
- In the English layout on 15 Nov 2026, the 2 `Play` buttons were at about 380,1728 to 495,1844 and 886,1728 to 1001,1844. Use them only to check that you picked the right node.
