# Live Darbar verification map

This folder is the maintained source for proving what a listener of Live Darbar sees and hears.
Read this index, then use the matching feature file as the recipe.

## Baseline preconditions

- The Android emulator `live_darbar_api36` is booted as `emulator-5554`, and it is the only booted device.
- A debug build from this checkout runs on it (`flutter run -d emulator-5554 --print-dtd`).
- `scripts/doctor.sh` ends with `doctor: ok`.
- The language is English and the home screen is in front. The recipes use the English labels from `lib/l10n/app_en.arb`.
- Nothing plays: every play button's label is `Play`.

## Driving conventions

- Read `orca emulator ax --json`, then tap the centre of a node's `bounds`, divided by 1080 x 2400.
- Find nodes by their label text. Labels in the recipes are literal; keep their curly apostrophes (`’`).
- Wait for an end state by reading `ax` again, about once a second, for at most 20 s.
- Return to the baseline after each recipe: stop playback, go back to home.

## Proof

- Screenshots go to `evidence/<feature>/<NN>-<step>.png` through `scripts/shot.sh`.
- Each proof has the state before the action, the state after it, and a side effect where one exists (the media session for audio).
- Name the feature ID and the entry point in your report for each artifact.

## Feature entry contract

Each feature file has an H1, 1 paragraph on what the listener gets, then 4 H2s in this order:
`Sub-features`, `How to get to it (user POV)`, `Driving it with orca emulator`, `Gotchas`.

## Features

- [Live Kirtan](./live-kirtan.md) covers the live stream from Sri Harmandir Sahib: play, stop, the mini player. Proved 2026-11-15.
- [Hukamnama reader](./hukamnama.md) covers today's Hukamnama text, its meaning, text size, and the SGPC links.
- [Daily recordings](./daily-recordings.md) covers today's Hukamnama and Hukamnama Katha recordings.
