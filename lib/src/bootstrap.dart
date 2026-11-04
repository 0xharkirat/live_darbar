import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:live_darbar/src/views/launch_failure_app.dart';

/// Starts the app, and ends on a calm screen with a Retry when start-up fails.
///
/// [prepare] is the work before the first frame: the audio session, the media
/// session. [build] makes the app from what [prepare] made. Two things go
/// wrong, and both used to leave a blank screen:
///
/// * [prepare] throws. `runApp` never runs, and the phone shows the splash
///   for ever.
/// * The first frame fails to build. A release build draws a grey box, and
///   the listener cannot tell if the app is slow or broken.
///
/// Either way [LaunchFailureApp] takes the screen. Its Retry works the
/// start-up again: all of [prepare] if that failed, and only [build] if the
/// first frame failed, because the audio session starts once.
///
/// A widget that breaks after the first frame is not a start-up failure. It
/// shows the error widget of the build (a small, calm box in a release build,
/// see `installErrorView`), and the rest of the app stays.
///
/// [launch] is `runApp`. Only a test gives another.
Future<void> bootstrap<T>({
  required Future<T> Function() prepare,
  required Widget Function(T prepared) build,
  void Function(Widget app) launch = runApp,
}) =>
    _Bootstrap<T>(prepare: prepare, build: build, launch: launch).attempt();

class _Bootstrap<T> {
  _Bootstrap({required this.prepare, required this.build, required this.launch});

  final Future<T> Function() prepare;
  final Widget Function(T prepared) build;
  final void Function(Widget app) launch;

  late final T _prepared;
  bool _isPrepared = false;

  void _fail(Object error, StackTrace stack) {
    // The app has no crash service. The error goes where a developer reads it.
    debugPrint('Live Darbar did not start: $error');
    developer.log('Live Darbar did not start', error: error, stackTrace: stack);
    launch(LaunchFailureApp(onRetry: () => unawaited(attempt())));
  }

  Future<void> attempt() async {
    if (!_isPrepared) {
      try {
        _prepared = await prepare();
        _isPrepared = true;
      } catch (error, stack) {
        _fail(error, stack);
        return;
      }
    }

    // A widget that fails to build calls ErrorWidget.builder. Watch it until
    // the first frame is done, then put the default back.
    final previous = ErrorWidget.builder;
    var firstFrameFailed = false;
    ErrorWidget.builder = (details) {
      firstFrameFailed = true;
      return previous(details);
    };

    try {
      // A fresh key, so a retry builds the app from nothing and does not
      // reuse the state of the tree that failed.
      launch(KeyedSubtree(key: UniqueKey(), child: build(_prepared)));
    } catch (error, stack) {
      ErrorWidget.builder = previous;
      _fail(error, stack);
      return;
    }

    // After launch, so this is the callback of the first frame that has the
    // app in it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ErrorWidget.builder = previous;
      if (firstFrameFailed) {
        _fail(
          StateError('A widget failed to build in the first frame'),
          StackTrace.current,
        );
      }
    });
  }
}
