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
- Text follows the phone's size setting up to 2x (`kMaxTextScale`, set in `appBuilder`). Android stops at 2x. iOS goes on to 3.1x, and no screen fits a phone at that size. A smaller setting is left as it is.
- At a large size, a control with a fixed height grows with its text: the mini player (`MiniPlayer.heightOf`), the timeline and the language switch. On Home, the switch moves under the dates when it is wider than half the row.
- Words drawn on a painting stop at 1.3x (`kPaintingTextScale`). The hero card keeps its shape, and at 2x its title climbed over the LIVE badge. The same words are at full size in the mini player and the player.
- Test a layout at 2x with the real fonts (`test/support/load_fonts.dart`). The test font is about 1.7 times as wide as Geist, so it reports overflows that no phone shows.
- Every font file holds the glyphs it claims. Check a new font with `fonttools` before you bundle it: the 2.1 Noto Sans Gurmukhi files held 0 Gurmukhi glyphs.

### Shape

- Corners are continuous (`RoundedSuperellipseBorder`, `ClipRSuperellipse`), as on iOS.
- Radii: 28 for the hero, 20 for cards and tiles, 14 for controls.

### Haptics

- A selection tick (`HapticFeedback.selectionClick`) marks a choice, on the frame the choice changes. The play button, the source switcher, the sound quality choices, the language switch, the reader's meaning toggle and its A- and A+ buttons have it.
- A choice that is already made is quiet, and so is a button that is off. Opening a page, a sheet or a link is quiet.
- `test/widgets/haptics_test.dart` pins the list. Add a control to it, or leave it quiet.

## Components

| Component | File | Rule |
| --- | --- | --- |
| `Pressable` | `views/widgets/pressable.dart` | Every tappable thing bigger than an icon. Sinks to 97% on touch-down, on a spring (`Motion.pressSpring`, back on `Motion.releaseSpring`) that starts from the current scale and speed, so a quick tap does not stutter. Small targets add a `PressFill`, and a row in a group takes scale 1 and the fill alone. Choices set `selected` for the screen reader. |
| `showAppSheet` | `views/widgets/app_sheet.dart` | Every small bottom sheet, through 1 route (`AppSheetRoute`). It moves on a spring, in on `Motion.sheet` and out on the faster `Motion.sheetExit`. A finger moves it 1:1 from anywhere on it. On release the sheet keeps the finger's speed: a flick down closes it, a flick up keeps it, and a slow drag closes it past halfway. Pulled up, it resists. A list in a sheet takes `appSheetScrollController(context)`, so a swipe down at the top of the list moves the sheet. Reduce Motion: the sheet stays put and fades, and a finger still moves it. A tap on the dimmed area closes it. |
| `AppRoutes` | `views/app_router.dart` | Every pushed page, by name: `/hukamnama`, `/about`, `/history`. Push with `Navigator.pushNamed`, never with a bare route, so the web shows the page in the address bar. |
| `FadePageRoute` | `views/widgets/fade_page_route.dart` | How a page arrives on the web: a fade, 180 ms in and 120 ms out. iOS and Android keep the Cupertino slide and swipe back. |
| `AppNavBar` | `views/widgets/app_nav_bar.dart` | The bar of a pushed page. On the web it lines up with the page's column, and its back control always names the page it returns to. |
| `KeepScreenAwake` | `views/widgets/keep_screen_awake.dart` | Keeps the screen on while a page is open and the app is in front. Only the Hukamnama reader uses it: the listener reads it slowly with no touch. Every other page lets the phone lock, for privacy and battery. The SGPC PDF opens in the in-app browser, which the app cannot keep awake. |
| `LaunchFailureApp` | `views/launch_failure_app.dart` | The screen when start-up fails, before the first frame or in it (`lib/src/bootstrap.dart`). A static app with no providers or saved settings. Both languages together, no exception text, 1 gold Retry that stays in reach at 2x text. A widget that breaks later does not use it. |
| `ErrorView` | `views/widgets/error_view.dart` | What stands where a widget failed to build, in a release build: a small box that says "This part did not load" in English and Punjabi, with no exception, no stack and no alarm colour. A debug build keeps Flutter's red screen. `installErrorView()` sets it in `main()`, before `bootstrap`. |
| `InAppLink` | `views/widgets/in_app_link.dart` | A button that opens the in-app browser. Busy until the browser covers the app, so a second tap cannot open a second tab. |
| `BusyIcon` | `views/widgets/busy_icon.dart` | An icon that swaps for a spinner with a scale and blur cross-fade. |
| `Artwork` | `views/widgets/artwork.dart` | A painting in the app's corner shape. `preloadArtwork` decodes Home's 3 paintings before the first frame, while the native splash is up, so Home appears whole. |
| `PlayButton` | `views/widgets/play_button.dart` | 1 gold button per screen. Others use `glass` or `bare`. The glyph swaps in place: the new one enters over 180 ms from 95% with a fade, the old one leaves over 120 ms. Reduce Motion: a fade only. |
| `LiveBadge` | `views/widgets/live_badge.dart` | Red dot when idle, red bars when playing. No pulse. |
| `Equalizer` | `views/widgets/equalizer.dart` | The looping motion of sound. It runs only while sound plays. |
| `LoadingRing` | `views/widgets/loading_ring.dart` | The 1 loading ring: thin, gold, a short arc that turns. It shows nothing for 300 ms (`Motion.ringDelay`), then fades in, so a quick load leaves no flicker. A screen reader hears "Loading". It is the only looping motion besides the equalizer. Material's `CircularProgressIndicator` has no place here. |
| `Timeline` | `views/widgets/scrubber.dart` | A scrubber for recordings, a live rail for the broadcast. Same height. |
| `MiniPlayer` | `views/widgets/mini_player_widget.dart` | Appears after the first play, then stays. |
| `SourceSwitcher` | `views/widgets/source_switcher.dart` | Live, Hukamnama, Katha, inside the player. |
| `WhatsNewSheet` | `views/widgets/whats_new_sheet.dart` | The sheet of what is new: the release, 3 to 5 new things, 1 gold "Got it". It shows once, the first time the app opens after an update. See What's new. |
| `MaintenanceBanner` | `views/widgets/maintenance_banner.dart` | The calm strip under the offline banner while `release.json` has a `maintenance` message. It blocks nothing. See `docs/release-manifest.md`. |
| `UpdateSheet` (forced) | `views/widgets/update_sheet.dart` | The update sheet for a build below `minBuild`: it cannot be closed, and its 1 button goes to the store. See `docs/release-manifest.md`. |
| `ReminderPrompt` | `views/widgets/reminder_sheet.dart` | The reminder's sheet: the 1 question the first time the listener opens the Hukamnama reader, and the way to change it after. See Daily reminder. |
| `ReminderBell` | `views/widgets/reminder_bell.dart` | The bell in the top bar of the Hukamnama reader. It opens the reminder's sheet. |
| `ReminderSetting` | `views/widgets/reminder_setting.dart` | "Daily Hukamnama reminder": the switch and the time, in the About group beside the language. |
| `HistorySetting` | `views/widgets/history_setting.dart` | "Today in Sikh history notification": the switch, in the About group under the reminder. See Today in Sikh history. |
| `SettingSwitchRow` | `views/widgets/setting_switch_row.dart` | One switch row of the About group: icon, label, an optional line under it, and the switch. The whole row is the target. |
| `WidgetCard` | `views/widgets/widget_card.dart` | The 1 small card on Home that offers the home screen widget, once. See Add the widget. |
| `WidgetSteps` | `views/widgets/widget_steps_sheet.dart` | The sheet with 3 steps, for an iPhone and for an Android launcher that cannot pin. Each gets a film above the steps: an iPhone adding the widget, or a launcher doing it by hand. |
| `DemoFilmView` | `views/widgets/demo_film.dart` | A film in a phone frame like the film on darbar.live: muted, looped, with the taps drawn over it. The poster shows first, on an error, and under Reduce Motion. |
| `SettingsGroup` | `views/widgets/settings_group.dart` | An inset group of rows with hairlines, iOS Settings style. About and the Sikh history screen use it. |
| `WidgetSetting` | `views/widgets/widget_setting.dart` | The permanent "Home screen widget" row in the About group. |
| `SheetFrame` | `views/widgets/sheet_parts.dart` | The surface, grabber and padding of a small sheet, with its gold and quiet buttons. The reminder and the widget steps use it. |

## Screens

| Screen | File | Shape |
| --- | --- | --- |
| Home | `views/screens/home_screen.dart` | 1 hero, 2 tiles, 1 text card. Not a stack of equal rows. The "add the widget" card sits last, shows once, and never changes the order above it. |
| Now Playing | `views/screens/now_playing_screen.dart` | An iOS sheet over home, and the page behind it scales back. Drag down from anywhere on its top part, or tap the dimmed home above it, to close. 3 groups: the artwork and the title, the timeline and the controls, the source switch with the line about the stream. See Player spacing. |
| Hukamnama | `views/screens/hukamnama_screen.dart` | Gurmukhi first, meaning under each line. The top bar holds the reminder bell and the text size control. |
| Sikh history | `views/screens/history_screen.dart` | The whole Nanakshahi year of events, by month, like a calendar. Home's history line opens it. See Today in Sikh history. |
| About | `views/screens/about_screen.dart` | 1 scrolling page with grouped link rows. |

## List ends

Every scrolling list ends above the system navigation bar, and on Home above the mini player, so its last item is never hidden.

- The space is inside the scroll view, from the view's bottom padding (`MediaQuery.viewPaddingOf`), never a fixed number. The bar's height changes with the phone.
- Never a `SafeArea` around the scroll view. It shrinks the scrolling area, so an item is cut off as it reaches the bar instead of sliding under it. A `SafeArea` with `bottom: false` is fine for the sides.
- Home adds the bar and `MiniPlayer.heightOf`. A page built from slivers ends with a `SliverSafeArea`. The sheets and the player use `sheetPadding` or the same bottom padding in their scroll view.
- The player reads the view padding, not the padding: Flutter's Cupertino sheet replaces the padding its content sees, and with it the bottom.
- `test/widgets/list_ends_test.dart` sets a bottom padding of 34 points and checks each page, the player and each sheet.

## Player spacing

The full-screen player is 3 groups, so the eye reads 3 things.

| Gap | Size | Where |
| --- | --- | --- |
| Inside a group | 16 | The artwork to the title. The timeline to the controls. |
| Between groups | 32 | The title to the timeline's bar. The controls to the source switch. |

- Both sizes are on the 8 point grid the app already uses, and the second is twice the first.
- The timeline's box starts 10 points above its bar (`Timeline.barInset`), so the gap above it is 22. The bar sits 32 below the title, as the eye sees it.
- The line about the stream (reconnecting, low quality) belongs to the source switch. It takes no room while it is empty. While it shows, it sits 8 above the switch.
- The sound quality button stays at the top right, level with the drag handle. It is not part of the column.
- `test/widgets/player_spacing_test.dart` measures each gap.

## What's new

The first open after an update shows 1 calm sheet with the new things of that release, then never again for it.
A fresh install shows nothing.

### The notes

- 1 file for each release: `assets/whats_new/<major>.<minor>.json`. The next release adds a file and no code. The folder is declared in `pubspec.yaml`.
- A patch release (`3.1.2`) is the same release as `3.1`, so it has no file and shows nothing.
- The file holds `release` and 3 to 5 `items`. Each item has a `title` and a `body` in `en` and `pa`. The body is optional. An item with no title in both languages is dropped, and the sheet shows the first 5.
- `test/models/whats_new_test.dart` reads every file that ships: its name must match its release, it must have 3 to 5 items, and each item must be short and in both languages.
- To start the next one: copy `3.1.json` to `3.2.json`, change the `release` and the items. Bump `version` in `pubspec.yaml`.

### When it shows

`decideWhatsNew` (`lib/src/core/whats_new_rules.dart`) holds the rule, and `WhatsNewController` keeps the saved release (`whats_new_seen_release`).

| Case | What happens |
| --- | --- |
| The release was shown | Nothing. |
| Nothing saved, and nothing else saved: a fresh install | Records the release. Shows nothing. |
| Nothing saved, but the app has other saved settings: an update from a build before this | Shows the notes. |
| A newer release than the saved one, with a file | Shows the notes. |
| A newer release with no file | Records the release. Shows nothing. |

A listener who updates from a build that kept no record, and who changed nothing in the app, looks like a fresh install. They see nothing. That is on purpose: a missed note costs less than a note shown to someone who has just installed the app.

`showWhatsNewOnFirstOpen` follows the update offer and the reminder question:

- Home is the top route and at rest, and has been calm for 1.2 s (`whatsNewSettleProvider`). A sheet or a page that is open is waited out, not skipped.
- The app is on screen. A tap on the home screen widget, the car or Siri can start the app with no screen, and nothing opens then.
- The update offer comes first. It waits for the update check, so the offer opens its own sheet and the notes follow it.
- The release is marked seen when the sheet appears, so the notes show once even when the listener swipes them away.
- It gives up after 2 minutes. The next launch tries again.

## Home screen widget

Android and iPhone.
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

## Add the widget

The app offers the home screen widget in 2 places: 1 small card on Home, shown once, and a permanent row in About.
There is no onboarding flow.
Android and iPhone only. The web has no home screen, so it has neither.

`lib/src/core/widget_card_rules.dart` holds every rule (`shouldShowWidgetCard`).
`lib/src/controllers/widget_card_controller.dart` keeps the saved facts.
`lib/src/controllers/widget_placement_controller.dart` asks the phone where the widget is, and asks it to pin the widget.

### The card

| Part | Rule |
| --- | --- |
| Place | Under the Hukamnama card, above the About link. The order above it stays: live kirtan, the Hukamnama, then reading it. |
| Words | "Today's Hukamnama on your home screen", then 2 buttons: a gold "Add widget" and a quiet "Not now". |
| Picture | A real render of the widget, idle, in the app's language. It is on the left, and a screen reader skips it. |
| Motion | The card grows in 180 ms and leaves the same way. Reduce Motion shortens it. |

### When it shows

All of these hold:

1. The listener played the Hukamnama recording at least once. The app saves a flag when that playback starts, from any place: a tile, the player, the notification, the car, the widget.
2. This is a later visit: the app started again, or came back to the front, after that first play. It never shows on the visit that played.
3. The widget is not on the home screen. If the phone cannot say, the card waits.
4. The card was not on screen in an earlier visit. It shows once. About keeps the way back.
5. The listener did not tap "Not now". That hides it for good.
6. No sheet or page is open over Home. The card waits for the sheet to close, so the 1 time is not spent under it. A card that is already on screen stays when a sheet opens.

The app saves "shown" the moment the card appears, as the reminder question does.
The card waits 1.5 s after the app starts or comes to the front, so the update offer comes first.

### Add widget

| Platform | What happens |
| --- | --- |
| Android | `HomeWidget.isRequestPinWidgetSupported()`, then `HomeWidget.requestPinWidget(qualifiedAndroidName: kWidgetProviderClass)`. Android shows its own dialog. |
| Android, no pinning | The steps sheet: press and hold the home screen, tap Widgets, find Live Darbar and drag its widget to the home screen. |
| iPhone | No API adds a widget. The steps sheet shows a short clip of an iPhone doing it, above 3 steps: press and hold the home screen, tap Edit then Add Widget, search for Live Darbar and add the medium size. |

The words Edit and Add Widget stay in English in Punjabi, because iOS shows them in English.

### Is it on the home screen

`HomeWidget.getInstalledWidgets()` answers on both platforms. The iPhone widget is the one with `kIosWidgetKind`. Android names the provider class in full or in the short form (`.widget.LiveDarbarWidgetProvider`).
The app asks at launch, when it comes to the front, and when About opens. So the card goes away after the listener adds the widget.

### The About row

- Label "Home screen widget", with the line "Play without opening the app."
- Not added: the word "Add" in gold and a chevron. A tap does what "Add widget" does.
- Added: a check and "Added". A tap does nothing, so no second widget is pinned by habit. A screen reader hears "Added" as the value of the row.
- It sits in the settings group, under the Sikh history switch.

### The demo film

The steps sheet opens with `DemoFilmView`: a film of the phone adding the widget, above the 3 steps.
An iPhone sees an iPhone do it (19.3 s).
An Android phone sees a launcher do it by hand (16.5 s).
The film plays with the official `video_player` package: muted, looped, with no controls.

| Part | Rule |
| --- | --- |
| Files | `assets/videos/`: for each phone, an H.264 MP4 (30 fps, 540 px wide, no sound, `faststart`, under 450 KB) and a WebP poster (its first picture, about 15 KB). The iPhone film is 540 x 1174 and the Android film is 540 x 1116. A test fails if a film passes 450 KB, a poster 20 KB, or the folder 1 MB. |
| Made like | The film on darbar.live: a real recording, at a calm pace, with every wait over 0.6 s cut. The iPhone film is recorded on an iPhone 17 Pro simulator by the XCUITest driver in `tool/ios_widget_driver` (`testFilm`), which logs each tap. The Android film is a screen recording of an emulator, cut the same way. |
| Frame | The demo film's frame on darbar.live (`site/styles.css`, `.device`): a bezel of 3% of the width, a dark gradient and a hairline ring. The iPhone's corners are 16% outside and 13.5% inside. The Android frame is a little squarer. 172 points wide, about 360 tall. |
| Poster | It shows until the first picture is on screen, and the film then fades in over it in 240 ms. It stays when the film cannot play. |
| Taps | The film's taps are drawn over it, from the same numbers as the cursor on darbar.live (`site/demo.js`): a light dot glides from tap to tap, sinks where it presses, and sends out a ring. The dot follows the film's clock, so a loop shows the same taps. `TapMark` lists them: the times come from the driver's tap log on the iPhone, and from the frames on Android. |
| Pauses | When the app goes to the background, when the sheet closes, and when another route covers it. |
| Reduce Motion | No film plays. The frame shows the poster only, with no taps. |
| Sound | None. On Android, the player mixes with others, because ExoPlayer asks for audio focus on play, and the kirtan would pause. On iPhone, the player gives no audio option, because any value sets the category of the whole app's audio session. |
| Android build | `video_player` brings Media3 1.9.2 and `just_audio` brings 1.4.1. `android/build.gradle` sets 1.9.2 for the whole app. Play the live kirtan on a phone after a change to either package. |
| Screen reader | It skips the film. The 3 steps say the same. |
| Tests | A fake player (`test/support/fake_film_player.dart`) stands in for the plugin: playing, the poster, an error, Reduce Motion, and a pause on background and on close. `test/widgets/demo_film_test.dart` checks the taps and, with a fake platform, that the real player is muted and looped. `integration_test/demo_film_test.dart` plays both films with the real player on a device (`flutter test integration_test/demo_film_test.dart -d <id>`); it passed on an iPhone 17 Pro simulator and an API 36 emulator. |

### The picture

The picture is the real SwiftUI view of the iPhone widget, drawn on a Mac, not a copy drawn by hand.
The Android widget has the same 2 lines and 2 buttons, so the same 2 files serve both phones: `assets/images/widget_idle_en.png` and `assets/images/widget_idle_pa.png`.
The top line and the button names use the iPhone's system font, so on Android they differ a little from the real widget.

```sh
tool/widget_render/run.sh
```

Draw them again when the widget's view or its words change. `tool/widget_render/render.swift` holds the words of the recorded 2 November 2026 Hukamnama.

## Daily reminder

Android and iPhone only. The web cannot remind with the page closed, so it has no reminder and no control.
There is no server and no push: the phone keeps 1 repeating local notification.

| Part | Rule |
| --- | --- |
| Time | 7:00 in Amritsar (IST, `Asia/Kolkata`) until the listener picks another. SGPC's Hukamnama is out by about 6:15 there (3 November 2026: 06:16 on our mirror), so 7:00 is safe. |
| Zone | The phone keeps the schedule in the Amritsar zone, so the listener's own daylight saving never moves it. A time the listener picks stays on their own clock. |
| Words | "Today's Hukamnama", then "Read the Hukamnama from Sri Darbar Sahib." It cannot name the day's text, because 1 repeating notification keeps 1 text. The text follows the app's language and is set again when the language changes. |
| Tap | Opens the Hukamnama reader with `openHukamnamaReader`, also from a cold start (`openReaderFromReminder` waits for the navigator). It never stacks a second reader. |

### Asking once

The question belongs to the Hukamnama reader, not to Home.
The listener has just chosen to read the Hukamnama, so a reminder to read it makes sense there.
On Home at launch it competed with the update offer and lost: the offer is a route on the navigator, the launch check saw a page over Home and gave up, and nothing asked again when the offer closed.

1. The first time the reader opens, a sheet asks (`askAboutReminderOnFirstOpen`). Listeners who update see it once too.
2. The check waits. It needs the reader on top, finished sliding in, the app on screen, and 600 ms of calm. A sheet over the reader (the update offer) is waited out, not skipped.
3. The app marks the question as asked when the sheet appears, never before. "Remind me", "Not now", a swipe down and a tap on the dimmed area all leave it marked, so it never comes back.
4. The phone's own permission question comes only after "Remind me". Initialising the notification plugin asks nothing.
5. If the phone says no, the sheet says why, with 1 button. It does not close as if the reminder were on.
6. The check gives up after 2 minutes, and stops when the reader closes. The next open asks again.

Android 13 and newer: `MainActivity` already asks for `POST_NOTIFICATIONS` at launch, for the media notification. That dialog can come before this sheet.

### The bell

A bell in the top bar of the reader, before the text size controls. It is always there, so the reminder is never lost behind a "Not now".
It is a 44 point target. A filled bell means the reminder is on. The web and other platforms that cannot remind have no bell.

The bell opens the same sheet (`showReminderPrompt`):

- Reminder off: the question, "Remind me" and "Not now".
- Reminder on: when it comes, a gold "Change time" and a quiet "Turn off". "Change time" closes the sheet and opens the wheel.
- The phone blocks notifications: the sheet says so instead of "on".

### Which clock

- The sheet and the time row write "7:00 AM in Amritsar, 12:30 PM here". The second time is the listener's own clock for the same moment today, so it follows their daylight saving (`onListenersClock`). When both read the same, as in India, only the first shows.
- A time the listener picks shows as that time alone: "9:30 PM".
- The wheel starts on the local equivalent of the Amritsar time. "Done" without a turn keeps the Amritsar default. A turn makes the time the listener's own, and "Use Amritsar time" goes back.
- Both times follow the clock format. Punjabi writes 24-hour times ("19:00"), as Material does.

### Changing it in About

- The row "Daily Hukamnama reminder", in the same group as the language, because it is a setting like the language.
- 1 switch row. The whole row is the target, and the switch only shows the state.
- While it is on, a time row under it opens a sheet with a wheel and a gold "Done". Done saves. A swipe away keeps the old time.
- A message under the rows says what to do when the phone blocks notifications, or when it would not set the reminder. A switch that turns on and does nothing is worse than none.

### How it fires

- Android: `zonedSchedule`, inexact (`inexactAllowWhileIdle`), repeating on the time of day. It needs no exact-alarm permission and may move by a few minutes. The plugin's boot receiver sets it again after a reboot and an app update.
- iPhone: a repeating calendar trigger. `AppDelegate.swift` makes the app the notification center's delegate. The plugin needs that to show a reminder while the app is open, and to hear a tap.
- Both platforms read the repeat in the zone of the scheduled date. An Amritsar time is scheduled in `Asia/Kolkata`, so it stays 7:00 there through the listener's daylight saving. A time on the listener's own clock is scheduled in the phone's zone.
- The app sets the schedule again at launch and on return to the front. That fixes a time on the listener's own clock after a trip, because the phone keeps the zone the schedule was set in.
- A time that does not exist on the day the clocks go forward (2:30) starts the day after. Android repeats the wall-clock time of the first moment, so a 3:30 start would make every reminder 3:30 (`nextReminder`).
- The time zone comes from `flutter_timezone`. If the `timezone` package does not know its name, the zone is one with the phone's offset. UTC would give the wrong hour.

`lib/src/controllers/reminder_controller.dart` holds the rules, and `lib/src/services/reminder_platform.dart` is the only code that knows the plugin.
`test/services/reminder_platform_test.dart` checks the messages the app sends the plugin.

## Today in Sikh history

The line on home has no setting. The notification is the listener's choice: a switch in About, off by default, never asked for with a sheet. It is for days with an event only, and the "Next" line does not change it.

| Part | Rule |
| --- | --- |
| Data | `assets/data/sgpc_events_<year>.json`, 1 file for each Nanakshahi year, from SGPC's calendar. The file lists its sources. |
| Next year | Add `sgpc_events_559.json` to `assets/data/`. `loadSgpcEvents` finds the files by name and `pubspec.yaml` bundles the folder, so no code changes. |
| Day | The SGPC day (Amritsar), the same day as the Sikh date above the events. |
| Range | An event with `gregorianEnd` falls on each day from `gregorian` to `gregorianEnd`. |
| Review | An event with `needsReview` is skipped. The app shows it after a Punjabi reader checks it and removes the flag. |

### On home

- 1 quiet line under the two dates, always 1 row of the same height: room for 2 lines of text, so live kirtan below it does not move from one day to the next. A title that needs more is cut after 2 lines, and the screen has it whole.
- A day with events: a gold "Today", then the first event in the app's language (English falls back to the Punjabi title), and "+N" in gold when the day has N more.
- A day with no event: a gold "Next · 8 Nov", then the next event to come. The date is written as the widget writes it (`widgetDate`), in Gurmukhi digits in Punjabi: "ਅਗਲਾ · ੮ ਨਵੰ". "+N" shows when that day has more events.
- The next event is searched in every loaded file (`SgpcEventTable.after`), so the last event of one year is followed by the first of the next year's file when the app has it. With no event left, the line is not there and the page is as it was before this existed.
- A thin gold rule at the left and a small chevron at the right. It is not a card, so the order below it stays: live kirtan, the Hukamnama, then reading it.
- The whole line is 1 target of 44 points or more. It opens the Sikh history screen.
- Gurmukhi has no letter spacing, and "+N" uses Gurmukhi digits in Punjabi.
- A screen reader reads 1 label. An event day: "Today in Sikh history: ", the first title, then "and 2 more". A quiet day: "Next in Sikh history, 8 November: ", the title.
- The line grows in 180 ms when the events arrive. Reduce Motion shortens it.
- "Today" is the SGPC day, the same day as the Sikh date above the line (`homeHistoryProvider`).

### The screen

`/history`, opened by the line on Home. It lists the Nanakshahi year that today falls in (14 March to 13 March), from the same event files.

| Part | Rule |
| --- | --- |
| Top | The title "Sikh history" (short, so the large title fits), a line that names the year and the source, and the "Today in Sikh history notification" switch in a `SettingsGroup`. The switch is where the platform can notify, as in About. |
| Months | A gold heading for each month ("NOVEMBER 2026"), then 1 row for each day that has an event. Months run from March. |
| Row | The day on the left in the serif, with its weekday under it, and the titles on the right. An event of several days is on its first day, with the range ("12-14"). Titles wrap and are never cut. |
| Past | Muted text. |
| Today | A gold wash, the date in gold and a small "Today" above the titles. A row counts as today on each day its event covers. |
| Upcoming | The brighter text. |
| Open | Scrolled to today, a little below the top so a few past days show above it. With no event today, to the next day that has one. The page stays clear until the scroll is set, so it never shows the top first. |

The notification switch sits above the first month, so the page opens below it. Scroll up to reach it.

`lib/src/core/history_calendar.dart` builds the year (`buildHistoryYear`), and `lib/src/controllers/history_year_controller.dart` gives it to the screen.

### The notification

- About, under the daily reminder, as "Today in Sikh history notification". Android and iPhone only, like the reminder.
- Off by default. The phone's permission question comes when the listener turns it on, and only if the reminder has not asked already.
- 1 notification for each day with an event, for the next 30 days (`planHistory`). The body has 1 title on each line. At most 30 are pending, and the reminder holds 1, far under the 64 of iOS.
- It fires once, on its day, at the time of the daily reminder: 7:00 in Amritsar by default, on the clock of the reminder's zone (see Which clock). If the listener changes the reminder time, the notifications follow.
- Quiet: Android channel `sikh_history` at low importance, no sound on iPhone.
- The app sets them again at launch, on return to the front, and when the language or the reminder time changes. Each set replaces the ids 100 to 129 and removes the rest.
- A tap opens the app. It does not open the Hukamnama reader.

`lib/src/controllers/sikh_history_controller.dart` holds the rules. `ReminderPlatform` is the only code that knows the plugin.

## Motion

- Respond on touch-down, within 120 ms.
- Enter and exit with `Motion.easeOut`. Never ease-in.
- UI animations stay at 300 ms or less.
- Anything a finger drags is a spring.
- The mini player opens the player on a spring that starts at the finger's speed (`showNowPlaying(flickVelocity:)`).
  A tap opens it on `Motion.sheet`. A flick uses `Motion.sheetFlick`, which has a hair of bounce, because a flick gave the sheet momentum.
  The Cupertino sheet draws its controller through a curve, so `SpringThroughCurve` plays the spring back through the inverse of that curve.
  A swipe up opens the player after a flick (200 points per second) or a slow pull (24 points past the touch slop).
- A sheet moves on a spring that starts at the finger's speed. It leaves faster than it came (`Motion.sheetExit`, 240 ms against 380 ms).
  `AppSheetRoute` holds the place of the sheet in 1 value, so a drag, a flick and the end of a spring are the same motion.
  A scroll view that lays out while the sheet opens must not end it: only a finger holding the sheet counts.
- The artwork grows when sound plays and settles back when it stops.
  It scales with `SpringScale` on `Motion.artwork`, which keeps its speed when play and pause alternate.
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
- The browser tab names the page on top: `Hukamnama · Live Darbar`, `About this app · Live Darbar`, and `Live Darbar` for Home, in the listener's language (`BrowserTitle`, `views/browser_title.dart`).
  It follows the navigator (`PageNames`), not a `Title` on each page: a page under another is not rebuilt when the top page closes, so the tab would keep the closed page's name. A sheet does not rename the tab. A phone app sets no title.
- Every vertical list has a scrollbar on the web, on any browser, and a phone app has none (`AppScrollBehavior`, `views/app_scroll_behavior.dart`). Flutter's own behavior draws one only when the browser reports a desktop system.
- A link to the app shows a card: Open Graph and `twitter:` meta in `web/index.html`, with the landing page's painting (`https://darbar.live/img/og.jpg`, 1200 x 630). A crawler ignores what follows the `#`, so every page shares 1 card. `site/` is not touched: the image is the landing page's own.
- `test/widgets/web_app_test.dart` holds the title, the scrollbars and the card. `test/widgets/navigation_test.dart` and `test/widgets/back_control_test.dart` hold these rules. `isWebProvider` lets a test stand in for the browser.

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
- Feed text shown as it came. Text from SGPC, the calendar of events and release.json goes through `displayText` (`lib/src/core/display_text.dart`) when a model reads it, so `null`, a blank string and the word "null" never reach the screen. A new feed field uses it too. `test/models/feed_null_test.dart` and `test/widgets/never_null_test.dart` hold the rule.
