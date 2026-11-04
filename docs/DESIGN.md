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

## Home screen widget

Android only for now. The iOS widget waits for the Apple developer membership.
The widget plays: a listener does not have to open the app.

| Part | Rule |
| --- | --- |
| Size | 1 layout, 4 x 2 cells: the top line, the Rahao line, and 2 buttons side by side. It is always 4 cells wide, because at 3 the button names are cut and at 2 the Rahao line has no room. It resizes in height only, from 2 rows up. |
| Top line | 1 line says what the widget is: `Hukamnama · 2 Nov · Ang 668`. The title is gold, and the rest muted. The date is the day of the Rahao line, so an old text names its own day. With no text, it is today's date. It shrinks from 13 sp to 11 sp before it cuts the Ang. |
| Line | The Rahao line in Gurmukhi, up to 2 lines. |
| Buttons | 2 buttons of the same size: `Hukamnama`, then `Live Kirtan` in gold. Each keeps its name in every state. Only the icon beside the name changes, so the listener always knows which button is which. |
| Taps | The 2 buttons play with no screen. A tap anywhere else opens the Hukamnama reader. The widget has no way to open the player. Its notification does that. |
| Targets | Each button is a 40 dp capsule in a 48 dp target, with a ripple that starts on touch-down. |
| Loading | A source that is opening shows a still "…" in place of its icon, and the button is dimmed. A widget cannot spin. |
| Screen reader | Each button says its name, its state, and what a double tap does: `Live kirtan, playing. Double tap to stop.` |
| Type | Gurbani is the app's Tiro Gurmukhi on Android 8 and newer. Older phones use the system serif. The top line and the button names use the phone's sans. No letter spacing, because Gurmukhi never gets it. |
| Size | Nothing is under 11 sp. Gurbani is never set under 12 sp. The button names are 14 sp. |

### States

The widget has 4 states: idle, loading, playing and paused. Each belongs to 1 source: live, the Hukamnama, or the Katha.

| State | Hukamnama button | Live Kirtan button |
| --- | --- | --- |
| Idle | Play | Play |
| Loading live | Play | Dimmed `…`, a tap cancels |
| Playing live | Play | Stop |
| Paused live | Play | Play |
| Loading the Hukamnama | Dimmed `…`, a tap cancels | Play |
| Playing the Hukamnama | Pause | Play |
| Paused Hukamnama | Play | Play |
| Katha, in any state | Play | Play |

Live has no pause, because the broadcast does not wait.
A tap on the button for another source switches to it.

### How a tap reaches the player

1. The launcher sends the tap to `WidgetControlReceiver`. No other app can reach it.
2. The widget writes "loading" for the source and draws again, so it answers at once.
3. The receiver starts audio_service's service as a foreground service. Android 12 and newer allow this from a widget tap.
4. The receiver binds to the media session and calls `playFromMediaId`, `pause` or `stop`, as Android Auto does. The ids are the ones in `MediaCatalog`: `0` live, `1` the Hukamnama.
5. The app plays, and `WidgetPlaybackSync` writes each state it reaches. The first one replaces the widget's own.

This works with the app process dead. If the app does not answer in 7 seconds, the receiver stops the service and the widget goes back to idle. The system ends an app that starts a foreground service and does not use it within 10 seconds.

### iPhone: how a tap reaches the player

On iOS 17 and newer, the 2 buttons play with no screen, like Android's.
On iOS 16, and for a tap away from the buttons, a link opens the app.
The Android rules above hold. Only the path differs.

1. Each button is a `Button(intent:)` of an `AudioPlaybackIntent` (`ios/Runner/WidgetPlayIntents.swift`). The system runs it in the app's process, not the widget's.
2. The file is a member of both the Runner target and the widget target. With the type in the widget alone, the system runs the intent in the widget, which may not play audio. Runner builds it with `LIVE_DARBAR_APP`, so the widget's copy compiles with no Flutter and does nothing.
3. `AppDelegate` owns the one Flutter engine and starts it in `didFinishLaunching`. A background launch for an intent has no screen, and the engine still runs. `SceneDelegate` shows the same engine when the listener opens the app, so the screen and the widget share one audio handler.
4. `perform()` writes "loading" for the source and redraws, then sends `tap` to Dart on the `widget_control` channel. Native retries while Dart is not listening yet.
5. `WidgetRemote` (`widget_remote.dart`) reads the real player, uses `widgetTapFor`, and answers once sound has started. A button on a stale picture is never trusted.

`tool/ios_widget_driver` drives the real tap on the simulator.

### How the state stays true

- The widget listens to the audio handler's playback state, so it follows the app, the notification, a headset, the car and the widget. A change reaches the widget in about 1 second.
- The state in the store carries the time of the write. A state from before the process started belongs to a session that ended, so the widget draws idle. It never says playing for a process that is gone.
- A force stop makes the launcher clear the widget, and the next draw says idle. A crash leaves the old state until the next draw: a tap on any control, the hourly update, a reboot, or the app starting. A tap on a stale stop button draws idle and starts nothing.
- A state that the widget wrote on a tap lapses after 15 seconds if the app never confirms it.

`lib/src/home_screen_widget/widget_playback.dart` writes the state, and `android/.../widget/WidgetPlayback.kt` holds the rules. The rules are plain Kotlin with a JVM test.

```sh
cd android && ./gradlew :app:testDebugUnitTest
```

A launcher draws the widget, so the Tiro Gurmukhi file lives in `res/font` as a copy of `assets/fonts/TiroGurmukhi-400.ttf`.
A test fails when the files differ.
Change both files together.

The text comes from Flutter, in the app's language, through `home_widget`.
`lib/src/home_screen_widget/` makes it, and `android/.../widget/` draws it.
The button names, and what a screen reader says for each button in each state, come from Flutter too, as `ld_labels`, because the widget changes state while the app is closed.
The colours in `res/values/widget.xml` copy `palette.dart`. Change both together.

The widget works out the day from the clock each time it draws.
Flutter writes a week of dates ahead, so the date stays right when the app does not run for days.
Only a new Hukamnama needs a fetch.
WorkManager fetches it at 00:10 and 09:00 India time, with the app closed.
Android can delay that work, so a widget with an old text always says which day the text is from.

The picker shows `res/layout/widget_preview.xml` on Android 12 and newer.
It is a still copy of the 4 x 2 layout, idle, with fixed text.
Change both layouts together.
Older phones show an image, which a test draws with the real fonts:

```sh
taskpolicy -b flutter test test/screens/widget_preview_test.dart --tags screens
cp build/screens/widget_preview.png android/app/src/main/res/drawable-nodpi/widget_preview.png
```

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
