import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/youtube_live.dart';
import 'package:live_darbar/src/models/youtube_live_check.dart';
import 'package:live_darbar/src/services/youtube_live_service.dart';

/// How often the app asks for the published file while it is in front.
///
/// The Action that writes the file runs every 5 minutes, so a faster ask would
/// only read the same answer again.
const kYoutubeLiveCheckEvery = Duration(minutes: 5);

final youtubeLiveServiceProvider = Provider<YoutubeLiveService>((ref) {
  final service = YoutubeLiveService();
  ref.onDispose(service.close);
  return service;
});

/// Whether the app is in front, or its state is not known yet (a test, or the
/// web before the first event).
bool _inFront() {
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

/// The latest published answer about SGPC's live streams, or null when there
/// is none to use: the file is missing, the phone is offline, or the file is
/// not the file. See [YoutubeLiveCheck] and [YoutubeLiveService.fetch].
///
/// It asks when it is first read (Home shows the row), and again every
/// [kYoutubeLiveCheckEvery] while the app is in front. A phone in the
/// background asks nothing: a timer that comes due there does nothing. The
/// screen invalidates this provider on resume, which asks at once.
///
/// While the next ask is on its way, the value is still the last answer, so
/// the row does not flicker.
final youtubeLiveCheckProvider = FutureProvider<YoutubeLiveCheck?>((ref) {
  final next = Timer(kYoutubeLiveCheckEvery, () {
    if (_inFront()) ref.invalidateSelf();
  });
  ref.onDispose(next.cancel);
  return ref.read(youtubeLiveServiceProvider).fetch();
});

/// The link the "Watch live on YouTube" row opens, or null when the row is
/// hidden.
///
/// The row follows the checked answer ([youtubeLiveCheckProvider]): the exact
/// video of the kirtan stream, else of the katha stream, and no row when only
/// audio is live. With no answer, or one that is not fresh, it falls back to
/// the timetable (`isYoutubeLiveWindow`) and the channel's live page. The rules
/// are in [youtubeLiveLink]. The first ask is still on its way for a moment
/// after launch: until it ends, there is no answer, so the timetable rules.
///
/// The provider moves on by itself: it sets a timer for the next timetable
/// edge, or for the moment a fresh answer goes stale, and invalidates itself
/// then. A phone that sleeps through an edge fires the timer when it wakes. A
/// screen can still invalidate on resume to be sure, because a timer can lag
/// while the app is in the background.
final youtubeLiveProvider = Provider<String?>((ref) {
  final check = ref.watch(youtubeLiveCheckProvider).value;
  // The timer and the answer come from one reading of the clock, so they
  // cannot disagree.
  final now = ref.read(clockProvider)();
  final next = Timer(untilYoutubeLinkChanges(now, check), ref.invalidateSelf);
  ref.onDispose(next.cancel);
  return youtubeLiveLink(now, check);
});
