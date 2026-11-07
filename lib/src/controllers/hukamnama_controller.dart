import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/hukamnama_cache.dart';
import 'package:live_darbar/src/services/hukamnama_loader.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';

final hukamnamaServiceProvider = Provider<HukamnamaService>((ref) {
  final service = HukamnamaService();
  ref.onDispose(service.close);
  return service;
});

final hukamnamaCacheProvider = Provider<HukamnamaCache>((ref) {
  return HukamnamaCache();
});

/// How long the controller waits between its own attempts to fetch today's
/// text, while the text it holds is not today's.
///
/// SGPC posts about 05:30 to 07:00 IST. A 15-minute step finds it within a
/// quarter of an hour of posting, and a night of waiting costs about 4
/// requests an hour.
const kHukamnamaRetryInterval = Duration(minutes: 15);

/// How many more times in a day the controller asks for today's line
/// meanings, while it holds today's text without them.
///
/// The mirror adds the lines some minutes after SGPC posts: on 7 November
/// 2026, an hour after. 8 asks, 15 minutes apart, wait about 2 hours. A day
/// that still has no lines then has none that day: the mirror could not match
/// its shabad.
const kHukamnamaLineRetries = 8;

/// The Hukamnama as text, for the most recent day available.
///
/// The value is a [Hukamnama] with its own [Hukamnama.date]. That date is not
/// always today. Until SGPC posts each morning, and whenever the phone cannot
/// reach the service, the newest text on hand is an earlier day's. The screen
/// must compare it with the SGPC day, read through `clockProvider`
/// (`hukamnama.isFor(sgpcDayOf(ref.read(clockProvider)()))`), and label an
/// earlier day as such. Yesterday's text must never be shown as
/// today's.
///
/// What the listener sees, in order:
/// 1. Today's text is on disk: it opens at once and nothing is fetched. A copy
///    with no line meanings (saved before the apps read them, or before the
///    mirror had the day) is fetched once more in the background.
/// 2. An earlier day's text is on disk: it opens at once as the value, and
///    today's is fetched in the background. If today's is not up yet, or the
///    phone is offline, the earlier text stays.
/// 3. Nothing on disk: the state is loading until the fetch ends. If today's
///    is not posted yet, yesterday's is fetched instead. If that fails too, the
///    state is an error, and [refresh] tries again.
///
/// A failed [refresh] never replaces text that is on screen with an error.
///
/// The controller refreshes itself at the start of each SGPC day, so an app
/// left open overnight asks for the new day without a resume. Before SGPC posts
/// that asks and, finding nothing newer, keeps the text on hand. A screen can
/// still call [refresh] on resume, and asking twice is safe.
///
/// It also retries on its own. While the text it holds is not today's (before
/// SGPC posts, or after a failure left it with yesterday's text or none), it
/// asks again every [kHukamnamaRetryInterval], for as long as it is alive. It
/// stops as soon as it holds today's text, and starts again at the next SGPC
/// midnight. This is the same on web, where the service reads the mirror.
///
/// Today's text with no line meanings is asked for again the same way, at most
/// [kHukamnamaLineRetries] times a day, and at once when the reader opens
/// ([refreshForLines]). The mirror can copy the day after SGPC posts it.
class HukamnamaController extends AsyncNotifier<Hukamnama> {
  Timer? _rollover;
  Timer? _retry;

  /// The SGPC day that [_lineRetries] counts for.
  DateTime? _lineRetriesDay;

  /// How many retries for line meanings ran on [_lineRetriesDay].
  int _lineRetries = 0;

  /// How many [refresh] calls are running. A retry that comes due while one is
  /// running does nothing, because that one re-arms the retry when it ends.
  int _refreshing = 0;

  @override
  Future<Hukamnama> build() async {
    _scheduleRollover();
    ref.onDispose(() {
      _rollover?.cancel();
      _retry?.cancel();
    });

    final Hukamnama opened;
    try {
      opened = await _open();
    } catch (_) {
      _syncRetry(null);
      rethrow;
    }
    _syncRetry(opened);
    return opened;
  }

  Future<Hukamnama> _open() async {
    final cache = ref.read(hukamnamaCacheProvider);
    final today = _today();

    final cachedToday = await cache.read(today);
    if (cachedToday != null) {
      if (cachedToday.shabad == null) _refreshAfterBuild();
      return cachedToday;
    }

    final earlier = await cache.readLatest();
    if (earlier != null) {
      _refreshAfterBuild();
      return earlier;
    }
    return _load(today);
  }

  /// Opens on the stored text at once, and looks for newer text afterward.
  /// The refresh runs as its own event, after this build has delivered its
  /// value, so the listener sees the text first and then a loading state that
  /// still holds it. Looking for newer text is not a reason to keep the screen
  /// empty.
  void _refreshAfterBuild() => Timer.run(() {
        if (ref.mounted) unawaited(refresh());
      });

  /// Asks the service for the newest text again, keeping what is shown
  /// meanwhile.
  ///
  /// Call it from pull to refresh, from a retry button, and when the app
  /// resumes, so a phone left open across SGPC's midnight picks up the new day.
  /// While it runs the state is loading with the earlier text still readable
  /// as `value`.
  ///
  /// Refreshes may overlap, and they can end in any order. A slower one never
  /// undoes a faster one: a result older than the text already in the state is
  /// dropped, and so is an error once there is text to show.
  Future<void> refresh() async {
    final shown = state.value;
    state = const AsyncLoading<Hukamnama>();
    _refreshing++;
    try {
      final fresh = await _load(_today(), have: shown);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null && fresh.date.isBefore(current.date)) return;
      state = AsyncData(fresh);
    } catch (e, st) {
      if (ref.mounted && !state.hasValue) state = AsyncError(e, st);
    } finally {
      _refreshing--;
      if (ref.mounted) {
        _scheduleRollover();
        _syncRetry(state.value);
      }
    }
  }

  /// Asks again for today's line meanings when the text on screen is today's
  /// and has none. The reader calls it when it opens, so a listener who opens
  /// it after the mirror copied the day sees the lines without waiting for the
  /// next retry. It does nothing while a refresh runs, and nothing for an
  /// earlier day's text, which has its own retry.
  void refreshForLines() {
    final shown = state.value;
    if (shown == null || shown.shabad != null || _refreshing > 0) return;
    if (!shown.isFor(_today())) return;
    unawaited(refresh());
  }

  DateTime _today() => sgpcDayOf(ref.read(clockProvider)());

  /// Arms one timer for the start of the next SGPC day, replacing any other.
  void _scheduleRollover() {
    _rollover?.cancel();
    _rollover = Timer(untilNextSgpcDay(ref.read(clockProvider)()), () {
      if (ref.mounted) unawaited(refresh());
    });
  }

  /// Arms one retry timer when [shown] is not today's text, or is today's
  /// with no line meanings and the day has retries left. Else none.
  ///
  /// [shown] is null when there is nothing to show, which is a failure to
  /// retry as well. Any timer already armed is replaced, so calling this after
  /// every result keeps exactly one in step with what is on screen. The timer
  /// is one-shot and the next [refresh] arms the one after it, so attempts
  /// never overlap and the gap is counted from the end of the last attempt.
  void _syncRetry(Hukamnama? shown) {
    _retry?.cancel();
    _retry = null;
    if (!ref.mounted) return;

    final today = _today();
    final forLines = shown != null && shown.isFor(today);
    if (forLines) {
      if (shown.shabad != null) return;
      if (_lineRetriesDay != today) {
        _lineRetriesDay = today;
        _lineRetries = 0;
      }
      if (_lineRetries >= kHukamnamaLineRetries) return;
    }

    _retry = Timer(kHukamnamaRetryInterval, () {
      _retry = null;
      if (!ref.mounted || _refreshing > 0) return;
      if (forLines) _lineRetries++;
      unawaited(refresh());
    });
  }

  /// The newest text the service has for [today]. See [loadLatestHukamnama].
  Future<Hukamnama> _load(DateTime today, {Hukamnama? have}) =>
      loadLatestHukamnama(
        service: ref.read(hukamnamaServiceProvider),
        cache: ref.read(hukamnamaCacheProvider),
        today: today,
        have: have,
      );
}

/// The latest Hukamnama text. See [HukamnamaController].
final hukamnamaProvider = AsyncNotifierProvider<HukamnamaController, Hukamnama>(
  HukamnamaController.new,
  // A failed build is shown as an error with a retry button. Riverpod's
  // default is to retry a failing build by itself, up to 10 times, behind the
  // listener's back. This feature already has an explicit way to try again.
  retry: (retryCount, error) => null,
);

/// The Hukamnama of an earlier day, for the reader that opens it.
///
/// [day] is an SGPC day, as UTC midnight (`parseSgpcDay`, `sgpcDayOf`). It is
/// asked of the service as it is, so the native apps read SGPC's archive and
/// the web reads its copy (see [HukamnamaService.fetch]). A day with no text
/// is a [HukamnamaNotPublishedException]; a phone that is offline gets the
/// client's own error.
///
/// An earlier day never changes, so a text that was read stays for the rest of
/// the session and reopening the day asks nothing. It is not stored on disk:
/// the stored text is today's, for the controller above and the home screen
/// widget. A failure is not kept, and nothing retries it behind the reader's
/// back. The reader has a retry button, which invalidates this.
final hukamnamaForDayProvider =
    FutureProvider.autoDispose.family<Hukamnama, DateTime>(
  (ref, day) async {
    final read = await ref.watch(hukamnamaServiceProvider).fetch(day);
    ref.keepAlive();
    return read;
  },
  retry: (retryCount, error) => null,
);
