import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/platform.dart';
import 'package:live_darbar/src/core/review_rules.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The store's rating sheet and listing, behind a seam a test can replace.
///
/// Each call swallows its failure: a rating is never worth an error the
/// listener can do nothing about.
class ReviewPlatform {
  const ReviewPlatform();

  /// The quiet, in-app rating sheet. The platform decides whether it really
  /// shows (Apple allows 3 a year, and Google has its own quota), and never
  /// says whether it did.
  Future<bool> requestReview() async {
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return false;
      await review.requestReview();
      return true;
    } catch (e) {
      if (!kReleaseMode) debugPrint('[review] sheet not shown: $e');
      return false;
    }
  }

  /// The app's page in the store, for a tap on "Rate Live Darbar". Google
  /// asks that a button never call the quota-limited sheet, so the row goes
  /// to the listing instead.
  Future<void> openStoreListing() async {
    try {
      await InAppReview.instance.openStoreListing(appStoreId: kAppStoreId);
    } catch (e) {
      if (!kReleaseMode) debugPrint('[review] store not opened: $e');
    }
  }
}

final reviewPlatformProvider = Provider<ReviewPlatform>(
  (ref) => const ReviewPlatform(),
);

/// Whether the app is on screen now. A provider so a test can say.
final appInForegroundProvider = Provider<bool Function()>(
  (ref) =>
      () => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
);

/// Counts listens, and asks once for each version for a store rating, after
/// [kListensBeforeReview] of them. See review_rules.dart for every rule.
///
/// It listens to the player from any place (a tile, the notification, the
/// car, the widget), so a listen counts however it started. It asks only when
/// the listener pauses a long listen with the app on screen.
class ReviewPromptController extends Notifier<void> {
  static const listensKey = 'review_listens';
  static const askedVersionKey = 'review_asked_version';

  final _tracker = ListenTracker();

  /// 1 job at a time, so 2 stops close together cannot both read the count
  /// before either has saved it.
  Future<void> _queue = Future.value();

  /// Bumped by every player event, so a job can tell that something happened
  /// since the pause that queued it.
  int _event = 0;

  /// Whether the pause that queued a job is still the latest thing that
  /// happened: same event, app on screen, player still paused.
  bool _stillPaused(int event) =>
      event == _event &&
      ref.mounted &&
      ref.read(appInForegroundProvider)() &&
      !ref.read(nowPlayingProvider).isPlaying;

  @override
  void build() {
    // The web has no store sheet.
    if (ref.watch(isWebProvider)) return;
    ref.listen<NowPlaying>(nowPlayingProvider, _onPlayer);
  }

  void _onPlayer(NowPlaying? previous, NowPlaying next) {
    final now = ref.read(clockProvider)();
    final event = ++_event;
    if (next.isPlaying) {
      _tracker.started(now);
      return;
    }
    final counted = _tracker.stopped(now);
    // A pause shows the play button. A stall shows the spinner, and an end or
    // a failure shows its own; none of those is the listener taking a break.
    final paused = (previous?.isPlaying ?? false) &&
        next.action == PlayAction.play &&
        _tracker.meaningful &&
        ref.read(appInForegroundProvider)();
    if (!counted && !paused) return;
    _queue = _queue.then(
        (_) => _afterListen(counted: counted, paused: paused, event: event));
  }

  Future<void> _afterListen({
    required bool counted,
    required bool paused,
    required int event,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var listens = prefs.getInt(listensKey) ?? 0;
      if (counted) {
        listens += 1;
        await prefs.setInt(listensKey, listens);
      }
      if (!paused || !ref.mounted) return;

      final version = await ref.read(appVersionProvider.future);
      if (!ref.mounted) return;
      final ask = shouldAskForReview(
        ReviewFacts(
          listens: listens,
          version: version,
          askedVersion: prefs.getString(askedVersionKey),
          listenerPaused: paused,
          foreground: ref.read(appInForegroundProvider)(),
        ),
      );
      if (!ask || !_stillPaused(event)) return;
      // Saved first: if the sheet fails, it still does not come back in this
      // version.
      await prefs.setString(askedVersionKey, version);
      if (!_stillPaused(event)) {
        // The listener came back during the write: do not spend the ask.
        await prefs.remove(askedVersionKey);
        return;
      }
      await ref.read(reviewPlatformProvider).requestReview();
    } catch (e) {
      if (!kReleaseMode) debugPrint('[review] listen not saved: $e');
    }
  }
}

final reviewPromptProvider = NotifierProvider<ReviewPromptController, void>(
  ReviewPromptController.new,
);
