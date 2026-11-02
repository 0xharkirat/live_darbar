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

- Titles: Geist Serif (the face darbar.live uses), with Tiro Gurmukhi behind it, so a title is serif in either language.
- Geist Serif and Tiro Gurmukhi each have 1 weight, 400. Titles and Gurbani are 400 in both languages. A 600 request would get a synthesized bold, which adds about 15% ink and smears the strokes.
- Everything else: Geist, the sans that pairs with Geist Serif and the face of darbar.live, with Noto Sans Gurmukhi behind it.
- Cupertino widgets take their type from the Cupertino theme, which defaults to the system font. `AppTheme` sets that theme in Geist, so the back label is not Roboto on the web.
- The font manifest declares a family named Roboto, which is Geist. Without it CanvasKit downloads Roboto from fonts.gstatic.com on every load. `test/widgets/app_fonts_test.dart` fails if any text leaves the bundled fonts.
- Gurbani: Tiro Gurmukhi.
- Large titles pull letters in. Small labels let them out.
- Every font file holds the glyphs it claims. Check a new font with `fonttools` before you bundle it: the 2.1 Noto Sans Gurmukhi files held 0 Gurmukhi glyphs.

### Shape

- Corners are continuous (`RoundedSuperellipseBorder`, `ClipRSuperellipse`), as on iOS.
- Radii: 28 for the hero, 20 for cards and tiles, 14 for controls.

## Components

| Component | File | Rule |
| --- | --- | --- |
| `Pressable` | `views/widgets/pressable.dart` | Every tappable thing bigger than an icon. Sinks to 97% on touch-down. Small targets add a `PressFill`, and a row in a group takes scale 1 and the fill alone. Choices set `selected` for the screen reader. |
| `showAppSheet` | `views/widgets/app_sheet.dart` | Every bottom sheet. Drawer curve in, faster exit. Reduce Motion: the sheet stays put and fades. A tap on the dimmed area closes it. |
| `AppRoutes` | `views/app_router.dart` | Every pushed page, by name: `/hukamnama`, `/about`. Push with `Navigator.pushNamed`, never with a bare route, so the web shows the page in the address bar. |
| `FadePageRoute` | `views/widgets/fade_page_route.dart` | How a page arrives on the web: a fade, 180 ms in and 120 ms out. iOS and Android keep the Cupertino slide and swipe back. |
| `AppNavBar` | `views/widgets/app_nav_bar.dart` | The bar of a pushed page. On the web it lines up with the page's column, and its back control always names the page it returns to. |
| `InAppLink` | `views/widgets/in_app_link.dart` | A button that opens the in-app browser. Busy until the browser covers the app, so a second tap cannot open a second tab. |
| `BusyIcon` | `views/widgets/busy_icon.dart` | An icon that swaps for a spinner with a scale and blur cross-fade. |
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
| Now Playing | `views/screens/now_playing_screen.dart` | An iOS sheet over home. Drag down, or tap the dimmed home above it, to close. |
| Hukamnama | `views/screens/hukamnama_screen.dart` | Gurmukhi first, meaning under each line, own text size control. |
| About | `views/screens/about_screen.dart` | 1 scrolling page with grouped link rows. |

## Motion

- Respond on touch-down, within 120 ms.
- Enter and exit with `Motion.easeOut`. Never ease-in.
- UI animations stay at 300 ms or less.
- Anything a finger drags is a spring.
- The artwork grows when sound plays and settles back when it stops.
- Reduce Motion swaps movement for a short fade. It keeps the feedback.
- Flutter runs every `AnimationController` at 5% of its length when Reduce Motion is on, so a fade is one frame long.
  Where a fade must be seen, give the controller `AnimationBehavior.preserve`, as `showAppSheet` does.

## The web

The web app is served from `/app/`, under darbar.live, by a static host with no rewrite rule.

- A page's address goes after the `#`: `/app/#/hukamnama`. A path such as `/app/hukamnama` would answer 404 on reload, and `/app/` must keep loading home.
- A link to a page opens home with the page over it, so back has somewhere to go. An unknown address opens home.
- The browser's back button calls the navigator's own pop (single-entry history), so it closes the top route: a page, or a sheet.
- A page fades in. A phone's slide from the right reads as a native app pretending, and it pairs with a swipe back that a mouse does not have.
- Every pushed page shows a back control. The window can be far wider than the column, so the control sits at the column's edge, not the window's.
- `test/widgets/navigation_test.dart` and `test/widgets/back_control_test.dart` hold these rules. `isWebProvider` lets a test stand in for the browser.

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
  Sound quality is a setting to set once, so its control is quiet, but it still has a word on it.
  `QualityButton` is a capsule at the top right of the player: a waveform icon and "Sound quality".
  A sliders icon alone said "settings" and nothing else.
  Data saver shows as a small pill beside the LIVE badge, and a tap on it opens the same sheet.
  The badge row keeps the pill's height with or without the pill, so the layout never jumps.
- Queue, shuffle, playback speed, listener counts, or streaks. The 2026-08 player research rejected each one for a devotional app.
