---
name: verify-live-darbar
description: Drive the real Live Darbar Flutter app on the Android emulator (then the iOS Simulator and the web build) the way a listener does, and save screenshot proof. Use before a Live Darbar UI task counts as done, for each feature the change touches, after tool/verify passes.
---

# Verify Live Darbar

Prove a feature in the running app, not in a widget test.
`tool/verify` covers format, analysis, and tests. This skill covers what a listener sees and hears.

Read [`features/README.md`](features/README.md), then the file for each feature that the change touches.
Each feature file is the recipe: entry points, labels, the end state that proves it.

## Devices

Use 1 device at a time. Stop one before you start the next.

1. **Android emulator**, AVD `live_darbar_api36`. This is the primary device. Every recipe in `features/` targets it.
2. **iOS Simulator**. Run the feature's `integration_test` journey there. Drive it by hand through the `orca-emulator` skill only when the feature has no journey yet.
3. **Web**, because the app has a web target. Run journeys with `flutter drive -d web-server`. Drive by hand with `flutter run -d web-server --web-port 8099` and Playwright.
4. **Physical devices** are a manual step for Hark before a release. Leave them to him; the skill never automates them.

The macOS desktop build is out of scope. The factory never verifies it.

Only the Android recipe was proved end to end (2026-11-15, Live Kirtan).
The iOS and web paths are unproven. The first run on each fixes this file.

## Repeat journeys

When a journey must run more than once (a regression, each release), write it as an `integration_test` test, not as a chat recipe:
`integration_test/<feature>_test.dart`, run with `taskpolicy -b flutter test integration_test/<feature>_test.dart -d <device>`.
The 3 files in `integration_test/` today are recording rigs for the site films, not journeys. Do not count them as coverage.

## Launch (Android)

1. Run `orca emulator attach live_darbar_api36 --json`. It boots the AVD and makes it the worktree's device, `emulator-5554`.
2. Run `taskpolicy -b flutter run -d emulator-5554 --print-dtd` in the background, with stdout in a log file.
   Ready means the log shows `The Dart Tooling Daemon is available at: ws://...`. A cold Gradle build takes about 4 min.
3. Optional: connect the Dart MCP `dtd` tool to that URI, then call `get_runtime_errors` after the journey.

The app reads the live network (stream, SGPC, ShabadOS). There is no seed data and no local server.

## Doctor

Run `.claude/skills/verify-live-darbar/scripts/doctor.sh [serial]` first, and again whenever something looks off.
It is read-only. It checks: exactly 1 booted device, the AVD name, the installed `versionName`, the app process, the app in front, and the network.
It ends with `doctor: ok` (exit 0) or `doctor: NOT OK` and a `FAIL` line for each problem.

## Drive (Android)

Use the `orca-emulator-android` skill (`orca skills get orca-emulator-android`). The loop:

1. Run `orca emulator ax --json`. Flutter semantics labels show as node text, with pixel `bounds`.
2. Tap the centre of the target's bounds: `orca emulator tap <x/1080> <y/2400> --json`. Taps take 0..1 coordinates; the screen is 1080 x 2400 (`adb shell wm size`).
3. Wait for the end state by reading `ax` again, about once a second, until the expected label shows. Do not use a fixed sleep.

Find controls by label, never by a hard-coded coordinate: the layout moves with the date, the language, and banners.
A play button's label is its state: `Play`, `Pause`, `Stop playback`, or `Retry`.

## Evidence

- Save screenshots with `.claude/skills/verify-live-darbar/scripts/shot.sh <feature> <NN-step>`.
  They land in `.claude/skills/verify-live-darbar/evidence/<feature>/`. Shrink them with `sips -Z 1200` before a commit; the repo is public.
- Capture the state before the action and after it, not only the last screen.
- Prove side effects too. For audio, save the media session line:
  `adb -s emulator-5554 shell dumpsys media_session | grep -m1 'state=PlaybackState' > <evidence>/<NN>-media-session.txt`.
  `PLAYING(3)` is sound; `PAUSED(2)` or `STOPPED(1)` is silence.
- Use only the user path: taps on the real UI. Never call a controller or a test-only hook to reach a state.
- Report an entry point you could not reach as a failure with its reason. Never report it as verified through a different entry point.

## Cleanup

Stop only what this run started. Evidence stays.

1. Stop your `flutter run` process. Kill it by its PID or its exact command line (`-d emulator-5554`), never by the name `flutter`.
2. Run `adb -s emulator-5554 shell am force-stop com.hsi.harki.live_darbar`.
3. Run `orca emulator shutdown --json` if this run booted the emulator. Otherwise run `orca emulator kill --json`, which leaves the device booted.
4. Run `ls .claude/skills/verify-live-darbar/evidence/<feature>/` and confirm the proof is still there.
