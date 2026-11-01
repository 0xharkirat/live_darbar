# Live Darbar design

The rules behind the 2.2 redesign.
Read this before you add or change a screen.

## Idea

Live Darbar is for listening at Amritvela, at night, and in the car.
Many listeners are older, and many read Gurmukhi slowly.
So the app is calm, dark, and large, and every control has a word on it.

The paintings by Kanwar Singh carry the character.
The UI around them stays quiet, so the paintings and the Gurbani come first.

## Tokens

All tokens live in `lib/src/core/`.

| File | Holds |
| --- | --- |
| `palette.dart` | Colours, each with its measured WCAG contrast |
| `app_type.dart` | The type scale |
| `motion.dart` | Curves, durations, springs |
| `app_theme.dart` | The Material theme built from the above |

### Colour

- The canvas is warm near-black `#0C0A09`. Dark only, by decision.
- Gold `#E8B04B` is the only accent. It is the colour of the Darbar Sahib in the paintings.
- Red `#FF453A` means 1 thing: the live broadcast. Errors use the same red on purpose.
- Body text clears 4.5:1 everywhere. `faint` (3.5:1) is for marks, never for text.

### Type

- Titles: Noto Serif, with Noto Serif Gurmukhi behind it, so a title has 1 voice in either language.
- Everything else: Manrope, with Noto Sans Gurmukhi behind it.
- Gurbani: Noto Serif Gurmukhi.
- Large titles pull letters in. Small labels let them out.
- Every font file holds the glyphs it claims. Check a new font with `fonttools` before you bundle it: the 2.1 Noto Sans Gurmukhi files held 0 Gurmukhi glyphs.

### Shape

- Corners are continuous (`RoundedSuperellipseBorder`, `ClipRSuperellipse`), as on iOS.
- Radii: 28 for the hero, 20 for cards and tiles, 14 for controls.

## Components

| Component | File | Rule |
| --- | --- | --- |
| `Pressable` | `views/widgets/pressable.dart` | Every tappable thing bigger than an icon. Sinks to 97% on touch-down. |
| `PlayButton` | `views/widgets/play_button.dart` | 1 gold button per screen. Others use `glass` or `bare`. |
| `LiveBadge` | `views/widgets/live_badge.dart` | Red dot when idle, red bars when playing. No pulse. |
| `Equalizer` | `views/widgets/equalizer.dart` | The only looping motion. It runs only while sound plays. |
| `Timeline` | `views/widgets/scrubber.dart` | A scrubber for recordings, a live rail for the broadcast. Same height. |
| `MiniPlayer` | `views/widgets/mini_player_widget.dart` | Appears after the first play, then stays. |
| `SourceSwitcher` | `views/widgets/source_switcher.dart` | Live, Hukamnama, Katha, inside the player. |

## Screens

| Screen | File | Shape |
| --- | --- | --- |
| Home | `views/screens/home_screen.dart` | 1 hero, 2 tiles, 1 text card. Not a stack of equal rows. |
| Now Playing | `views/screens/now_playing_screen.dart` | An iOS sheet over home. Drag down to close. |
| Hukamnama | `views/screens/hukamnama_screen.dart` | Gurmukhi first, meaning under each line, own text size control. |
| About | `views/screens/about_screen.dart` | 1 scrolling page with grouped link rows. |

## Motion

- Respond on touch-down, within 120 ms.
- Enter and exit with `Motion.easeOut`. Never ease-in.
- UI animations stay at 300 ms or less.
- Anything a finger drags is a spring.
- The artwork grows when sound plays and settles back when it stops.
- Reduce Motion swaps movement for a short fade. It keeps the feedback.

## Screenshots

`test/screens/screens_test.dart` renders every main screen at iPhone 17 Pro size, with the real fonts and paintings, into `build/screens/`.

```sh
flutter test test/screens --tags screens
```

Use it to check a change, and as the source for store screenshots.

## Do not add

- Grain, noise textures, or a moving background.
- A second accent colour, or a light theme.
- A row of identical bordered cards.
- An icon-only control for anything a first-time listener needs.
- Queue, shuffle, playback speed, listener counts, or streaks. The 2026-08 player research rejected each one for a devotional app.
