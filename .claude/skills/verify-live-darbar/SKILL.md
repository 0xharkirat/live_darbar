---
name: verify-live-darbar
description: Drive the real Live Darbar Flutter app on the Android emulator (then the iOS Simulator and the web build) the way a listener does, and save screenshot proof. Use before a Live Darbar UI task counts as done, for each feature the change touches, after tool/verify passes.
---

# Verify Live Darbar

Prove a feature in the running app, not in a widget test.
`tool/verify` covers format, analysis, and tests. This skill covers what a listener sees and hears.

Read [`features/README.md`](features/README.md), then the file for each feature that the change touches.
Each feature file is the recipe: entry points, labels, the end state that proves it.
When a touched feature has no file yet, write `features/<feature>.md` to the README contract as part of the change, then drive it.
If you cannot drive it, report that feature as not verified, with the reason.

Run every command from the repo root. `$SKILL` below means `.claude/skills/verify-live-darbar`.

## Devices

Use 1 device at a time. Stop one before you start the next.

1. **Android emulator**, AVD `live_darbar_api36`. This is the primary device. Every recipe in `features/` targets it.
2. **iOS Simulator**. Run the feature's `integration_test` journey there. Drive it by hand through the `orca-emulator` skill only when the feature has no journey yet.
3. **Web**, because the app has a web target. Run journeys with `flutter drive -d web-server`. Drive by hand with `flutter run -d web-server --web-port 8099` and Playwright.
4. **Physical devices** are a manual step for Hark before a release. Leave them to him.

The macOS desktop build is out of scope.

Only the Android recipe for Live Kirtan is proved end to end (2026-11-15).
The iOS and web paths are unproven. The first run on each fixes this file.

## Repeat journeys

When a journey must run more than once (a regression, each release), write it as an `integration_test` test:
`integration_test/<feature>_test.dart`, run with `taskpolicy -b flutter test integration_test/<feature>_test.dart -d <device>`.

Today's files:

- `integration_test/live_stream_reachability_test.dart` opens the live stream with the real player on a real device. It is the journey for `live-play` on iOS.
- `demo_film_test.dart` and `landing_film_test.dart` drive the landing-page films. They prove no feature.

## Launch (Android)

1. Run `orca emulator attach live_darbar_api36 --json`. Take the serial from `result.info.deviceUdid`, usually `emulator-5554`. Below it is `$SERIAL`.
2. Run `taskpolicy -b flutter run -d $SERIAL --print-dtd` in the background, with stdout in a log file.
   - Ready: the log shows `The Dart Tooling Daemon is available at: ws://...`. A cold Gradle build takes about 4 min.
   - Failed: the log shows `BUILD FAILED`, `Error:`, or the `flutter run` process ends. Stop and report the log lines.
   - Wait in 1 background loop that ends on either outcome, for at most 10 min.
3. Optional: connect the Dart MCP `dtd` tool to that URI, then call `get_runtime_errors` after the journey.

The app reads the live network (stream, SGPC, ShabadOS). There is no seed data and no local server.

## Doctor

Run `$SKILL/scripts/doctor.sh [$SERIAL]` after Launch, and again whenever something looks off.
It is read-only. It fails when any of these is wrong: exactly 1 booted device, AVD `live_darbar_api36`, boot complete, a 1080x2400 screen, the installed `versionName` equal to `pubspec.yaml`, the app running and in front, and the device reaching `live.sgpc.net`.
It ends with `doctor: ok` (exit 0) or `doctor: NOT OK` and a `FAIL` line for each problem.

## Drive (Android)

Use the `orca-emulator-android` skill (`orca skills get orca-emulator-android`). The loop:

1. Run `orca emulator ax --json`. Flutter semantics labels show as node text, with pixel `bounds`.
2. Tap the centre of the target's bounds: `orca emulator tap <x/1080> <y/2400> --json`. Taps take 0..1 coordinates.
3. Read `ax` again, about once a second, until the expected label shows. Stop after 20 s and report the step as failed, with the last `ax` labels.

Find controls by label in a fresh `ax` read. The bounds in the recipes are examples from 1 run; the layout moves with the date, the language, and banners.
A play button's label is its state: `Play`, `Pause`, `Stop playback`, or `Retry`.

## Evidence

- Save screenshots with `$SKILL/scripts/shot.sh <feature> <NN-step>`.
  They land in `$SKILL/evidence/<feature>/`, already shrunk to 1200 px tall. Commit only the shots that prove the change; the repo is public.
- Capture the state before the action and after it, not only the last screen.
- Prove side effects too. For audio, run `$SKILL/scripts/session.sh PLAYING > $SKILL/evidence/<feature>/<NN>-media-session.txt`.
  It prints Live Darbar's own session (`package=` and `state=` lines) and waits up to 20 s for the state.
  `PLAYING(3)` is sound. `PAUSED(2)` and `STOPPED(1)` are silence. `BUFFERING(6)`, `CONNECTING(8)`, and `ERROR(7)` are not a pass.
- Use only the user path: taps on the real UI. Reach every state through the UI, never through a controller or a test hook.
- Report an entry point you could not reach as a failure with its reason. Report only the entry points you drove as verified.

## Cleanup

Stop only what this run started. Evidence stays.

1. Stop your `flutter run` process by its PID or its exact command line (`-d $SERIAL`).
2. Run `adb -s $SERIAL shell am force-stop com.hsi.harki.live_darbar`.
3. Run `orca emulator shutdown --json` if this run booted the emulator. Otherwise run `orca emulator kill --json`, which leaves the device booted.
4. Run `ls $SKILL/evidence/<feature>/` and confirm the proof is still there.
