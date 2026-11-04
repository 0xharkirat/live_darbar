# Live Darbar

Live Darbar streams live kirtan from Sri Harmandir Sahib.
It also plays the daily Hukamnama and Katha.
It runs on Android, iPhone, and the web (darbar.live/app). Android also has a home screen widget.

- Stack: Flutter, Riverpod 3, just_audio with audio_service, home_widget.
- Code: `lib/src/{core,models,controllers,views}`.

## Check loop

The `dart-flutter` plugin gives you the Dart MCP server and the Dart and Flutter skills.
Use its tools instead of the CLI. Load them with ToolSearch, and call them by short name.

`analyze_files` on `lib/` takes 15.4 s on the 1st call and 0.0 s on the 2nd, because the analyzer stays warm.
`dart analyze lib` takes 7.1 s on every run.

The analyzer roots at the folder where the chat starts.
A folder with about 27,000 Dart files made 1 call take 3.5 min.
Start every chat for this app in the repo root.

1. After an edit, run `analyze_files` on the changed paths. Done when it reports 0 issues.
2. Run only the tests the change touches, in 1 call: `taskpolicy -b flutter test -j 4 <files>`.
3. Run the full suite only before a release.
4. For a UI change with the app running, call `dtd` with `listDtdUris`, then `connect`.
   `flutter run --print-dtd` prints the DTD URI.
5. Call `hot_reload`, then `get_runtime_errors`.
6. Call `widget_inspector` `get_widget_tree` with `summaryOnly`.
7. For a package API, read its source with `read_package_uris` and `rip_grep_packages`.
   Search pub.dev with `pub_dev_search`.

## Design

- The theme is dark only, with 1 palette: `lib/src/core/palette.dart`.
- Motion tokens live in `lib/src/core/motion.dart`. Design rules live in `docs/DESIGN.md`.
- Gurmukhi text takes no letter spacing. Spacing pushes the vowel signs off their letters.

## Text

- English and Punjabi live in `lib/l10n/*.arb`.
- Edit only the `.arb` files. Run `flutter gen-l10n` to regenerate the Dart files.

## Screens

- Render the screens to PNG: `flutter test test/screens --tags screens`.
- The images land in `build/screens/`.

## Releases

- Run `dart tool/release.dart` with `status`, `bump`, `notes`, `build --confirm`, or `live`.
- A Codemagic build publishes to the stores. Start one only when the owner asks for that release.
- Push only when the owner asks.
- This repo is public. Keys live in Codemagic, never in a commit.

## Machine load

- Start every heavy command (build, test, render) with `taskpolicy -b`.
- Use 4 or fewer test workers.
