# Hukamnama reader

The Hukamnama reader shows today's Hukamnama from Sri Harmandir Sahib as SGPC publishes it: the Gurmukhi text, the Ang, and the meaning in Punjabi or English.

## Sub-features

- `huk-open` opens the reader from home.
- `huk-text` shows the Gurmukhi text, the date, and the Ang.
- `huk-meaning` switches the meaning between Punjabi and English.
- `huk-size` makes the text larger or smaller.
- `huk-listen` plays today's Hukamnama recording from the reader.
- `huk-sgpc` opens SGPC's PDF of the Hukamnama. This recipe does not drive it yet.

## How to get to it (user POV)

- Tap the `Read today’s Hukamnama` card at the bottom of home (scroll down if it is off screen).
- Open `darbar.live/app/#/hukamnama` on the web build. This recipe does not drive the web.

## Driving it with orca emulator

Preconditions:

- The baseline in `README.md` holds.
- The reader text is at its smallest size, which is the default. The app saves the size, so an earlier run can leave it larger: tap `Smaller text` until the text stops shrinking.

- **Open.** Find the node whose label starts `Read today’s Hukamnama` and tap its centre. The reader opens; `ax` shows the `Hukamnama of <date>` heading and `Ang <n>`.
- **Text.** The Ang on the reader equals the Ang on the home card. The home card reads `READ TODAY’S HUKAMNAMA · ANG <n>`, or `HUKAMNAMA OF <date> · ANG <n>` before SGPC publishes.
- **Before size.** Run `$SKILL/scripts/shot.sh hukamnama 01-reader`.
- **Larger.** Tap `Larger text`, then run `$SKILL/scripts/shot.sh hukamnama 02-reader-larger`. Compared with `01-reader`, the text is larger.
- **Smaller.** Tap `Smaller text`. The text returns to the size in `01-reader`.
- **Meaning.** Under `Meaning`, tap the language that is not selected. The meaning text changes script.
- **Listen.** Tap `Listen`. Its label becomes `Pause`. Run `$SKILL/scripts/session.sh PLAYING > $SKILL/evidence/hukamnama/03-media-session.txt`; it exits 0. Tap `Pause` before you leave.
- **Back.** Run `orca emulator button back --json`. Home shows again.

## Gotchas

- Before SGPC publishes (early morning in Amritsar) the reader shows `Today’s Hukamnama is not out yet. This is the one from <date>.` That is correct behaviour, not a failure.
- On Android, when the text cannot load, the reader shows `Today’s Hukamnama text could not be loaded` with `Retry` and `SGPC PDF`. Report it with the network state. (`Read it on SGPC’s website` shows on the web build only.)
- `SGPC PDF` opens an in-app browser view over the reader. Take the screenshot before you tap it.
- Gurmukhi text takes no letter spacing. Vowel signs off their letters in a screenshot are a bug.
