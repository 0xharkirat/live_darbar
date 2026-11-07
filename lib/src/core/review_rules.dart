/// When the app may ask for a store rating, and what counts as a listen.
///
/// The ask is the platform's own review sheet (in_app_review), shown at most
/// once for each version of the app, and only after the listener has really
/// used it: [kListensBeforeReview] listens of [kMeaningfulListen] or more. It
/// is never shown at launch. A listen takes [kMeaningfulListen] of sound, so
/// the earliest ask is that long after the app starts.
library;

import 'package:flutter/foundation.dart';

/// How long the sound must play for a listen to count.
const kMeaningfulListen = Duration(minutes: 10);

/// How many listens come before the app asks once.
const kListensBeforeReview = 5;

/// A stop shorter than this does not end a listen: a stall on a weak network,
/// or a tap from 1 source to another. The time stopped is not counted.
const kListenGap = Duration(seconds: 30);

/// Turns the player's starts and stops into listens.
///
/// Feed it [started] each time sound starts and [stopped] each time it stops,
/// with the time of each. It holds no clock of its own, so a test can drive it.
class ListenTracker {
  DateTime? _since;
  DateTime? _stoppedAt;
  Duration _heard = Duration.zero;
  bool _counted = false;

  /// How long the current listen has played, up to its last stop.
  @visibleForTesting
  Duration get heard => _heard;

  /// The last listen, or the one now playing, has reached [kMeaningfulListen].
  bool get meaningful => _counted;

  /// Sound started at [now]. After a stop of [kListenGap] or more, this is a
  /// new listen; after a shorter one, the same listen goes on.
  void started(DateTime now) {
    if (_since != null) return;
    final stoppedAt = _stoppedAt;
    if (stoppedAt == null || now.difference(stoppedAt) >= kListenGap) {
      _heard = Duration.zero;
      _counted = false;
    }
    _since = now;
    _stoppedAt = null;
  }

  /// Sound stopped at [now]. True when this stop is the one that takes the
  /// listen past [kMeaningfulListen], which happens once for each listen.
  bool stopped(DateTime now) {
    final since = _since;
    if (since == null) return false;
    final played = now.difference(since);
    if (!played.isNegative) _heard += played;
    _since = null;
    _stoppedAt = now;
    if (_counted || _heard < kMeaningfulListen) return false;
    _counted = true;
    return true;
  }
}

/// Everything [shouldAskForReview] decides from.
@immutable
class ReviewFacts {
  const ReviewFacts({
    required this.listens,
    required this.version,
    required this.askedVersion,
    required this.listenerPaused,
    required this.foreground,
  });

  /// Saved. How many listens of [kMeaningfulListen] the app has counted.
  final int listens;

  /// The installed version.
  final String version;

  /// Saved. The version that last asked, or null if none has.
  final String? askedVersion;

  /// The listener has just paused a listen of [kMeaningfulListen] or more: a
  /// natural break, and not a stall or a failure.
  final bool listenerPaused;

  /// The app is on screen. A sheet asked for from the background is dropped
  /// by the platform, and would spend this version's 1 ask on nothing.
  final bool foreground;
}

/// Whether to ask for a rating now. See the library comment.
bool shouldAskForReview(ReviewFacts f) =>
    f.listens >= kListensBeforeReview &&
    f.askedVersion != f.version &&
    f.listenerPaused &&
    f.foreground;
