# Hukamnama reader

The Hukamnama reader shows today's Hukamnama from Sri Harmandir Sahib as SGPC publishes it: the Gurmukhi text, the Ang, and the meaning in Punjabi or English.

## Sub-features

- `huk-open` opens the reader from home.
- `huk-text` shows the Gurmukhi text, the date, and the Ang.
- `huk-meaning` switches the meaning between Punjabi and English.
- `huk-size` makes the text smaller or larger.
- `huk-listen` plays today's Hukamnama recording from the reader.
- `huk-sgpc` opens the SGPC PDF or SGPC's website.

## How to get to it (user POV)

- Tap the `Read today’s Hukamnama` card at the bottom of home (scroll down if it is off screen).
- Open `darbar.live/app/#/hukamnama` on the web build.

## Driving it with orca emulator

Preconditions:

- The baseline in `README.md` holds.

- **Open.** Find the node whose label starts `Read today’s Hukamnama` and tap its centre. The reader opens; `ax` shows the `Hukamnama of <date>` heading and `Ang <n>`.
- **Text.** The Ang on the reader equals the Ang on the home card (`READ TODAY’S HUKAMNAMA · ANG <n>`).
- **Meaning.** Under `Meaning`, tap the language that is not selected. The meaning text changes script.
- **Size.** Tap `Larger text`, then `Smaller text`. Compare 2 screenshots: the text grows, then shrinks.
- **Listen.** Tap `Listen`. Its label becomes `Pause`, and the media session shows `PLAYING(3)`.
- **Proof.** Run `scripts/shot.sh hukamnama 01-reader` after open and `02-reader-larger` after the size step.
- **Back.** Run `orca emulator button back --json`. Home shows again.

## Gotchas

- Before SGPC publishes (early morning in Amritsar) the reader shows `Today’s Hukamnama is not out yet. This is the one from <date>.` That is correct behaviour, not a failure.
- When the text cannot load, the reader shows `Today’s Hukamnama text could not be loaded` with `Retry` and `Read it on SGPC’s website`. Report it with the network state.
- `SGPC PDF` and the SGPC website open outside the app. Take the screenshot before you tap them.
- Gurmukhi text takes no letter spacing. Vowel signs off their letters in a screenshot are a bug.
