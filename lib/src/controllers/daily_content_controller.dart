import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:live_darbar/src/models/daily_edition.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// Works out which day's recording the app can actually play, and says so.
///
/// The problem this solves is that "today's Hukamnama" is not a thing that
/// exists all day. SGPC uploads the Hukamnama around 05:30 IST and the Katha
/// around 09:30 IST, so for several hours after midnight in Amritsar the dated
/// file the app wants is a 404. Pointing the player at it anyway would hand
/// [AudioController] a hard failure it would then retry on a backoff forever,
/// because a missing file does not become present by asking again.
///
/// So the day is settled before the player is touched, with one cheap HEAD,
/// and the answer is carried alongside the URL so the UI can be honest about
/// it. Falling back to yesterday is much better than a spinner, but only if
/// the listener is told.
class DailyContentResolver {
  DailyContentResolver({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _now = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;

  /// Long enough for a slow mobile connection. Both days are probed at once,
  /// so this is also the longest anyone waits on the probes in total.
  ///
  /// Any request without one of these is the bug that started this work:
  /// `hukamnamapdf.php` completes its TLS handshake and then sends nothing,
  /// and Dart's default client has no timeout of its own, so the future simply
  /// never completes and the spinner never resolves.
  static const _probeTimeout = Duration(seconds: 6);

  /// How long a non-today answer is trusted before it is worth asking again.
  ///
  /// A confirmed [DailyFreshness.today] cannot get any fresher, so it is held
  /// for the rest of the day. Everything else is a statement about a file that
  /// has not been uploaded yet, and it stops being true the moment it is, so
  /// it gets a short life instead. Someone with the app open at 05:25 IST sees
  /// today's Hukamnama on their next play rather than at their next launch.
  static const _staleRecheck = Duration(minutes: 10);

  final _cache = <DailyAsset, _Resolved>{};
  final _inFlight = <DailyAsset, Future<DailyEdition>>{};

  /// Resolve [asset] to a URL that will load, and to the day behind it.
  Future<DailyEdition> resolve(DailyAsset asset) {
    final today = sgpcDayOf(_now());

    final cached = _cache[asset];
    if (cached != null && cached.isValidOn(today, _now())) {
      return Future.value(cached.edition);
    }

    final existing = _inFlight[asset];
    if (existing != null) return existing;

    final future = _resolve(asset, today);
    _inFlight[asset] = future;
    future.whenComplete(() => _inFlight.remove(asset));
    return future;
  }

  Future<DailyEdition> _resolve(DailyAsset asset, DateTime today) async {
    // Web never gets past the probe. hs.sgpc.net sends no
    // `Access-Control-Allow-Origin`, so a HEAD from a browser is blocked
    // before it is sent, while an `<audio>` element loads the same URL
    // happily because media elements are exempt from CORS. Attempting it
    // anyway would cost every web listener a guaranteed failure and a console
    // error, so take the undated URL directly and say nothing about the day.
    if (kIsWeb || kIsWasm) return DailyEdition.latest(asset);

    // Both days are asked at once. Asked one after the other, a server that
    // accepts the connection and then goes quiet cost the full probe timeout
    // twice before anything played: 12 seconds of spinner on a weak link.
    // Together the worst case is one timeout, and the common case, where
    // today is up, is no slower than before because today's answer is taken
    // the moment it arrives without waiting for yesterday's. The spare probe
    // is one small HEAD, and `_exists` cannot throw, so letting it finish
    // unobserved is safe.
    final previous = previousSgpcDay(today);
    final todayProbe = _exists(asset.urlFor(today));
    final previousProbe = _exists(asset.urlFor(previous));

    if (await todayProbe) {
      return _remember(DailyEdition(
        asset: asset,
        url: asset.urlFor(today),
        freshness: DailyFreshness.today,
        day: today,
      ));
    }
    if (await previousProbe) {
      return _remember(DailyEdition(
        asset: asset,
        url: asset.urlFor(previous),
        freshness: DailyFreshness.previousDay,
        day: previous,
      ));
    }

    return _remember(DailyEdition.latest(asset));
  }

  DailyEdition _remember(DailyEdition edition) {
    _cache[edition.asset] = _Resolved(edition, _now());
    return edition;
  }

  Future<bool> _exists(String url) async {
    try {
      final response =
          await _client.head(Uri.parse(url)).timeout(_probeTimeout);
      return response.statusCode == 200;
    } catch (e) {
      // A probe that fails is not an error worth surfacing. It means the app
      // drops to the next candidate, and the worst outcome is the undated URL
      // the app used to hardcode. Same reasoning as the update check: a
      // courtesy that reports its own failure is worse than a quiet one.
      if (!kReleaseMode) debugPrint('[daily] probe failed for $url: $e');
      return false;
    }
  }

  void dispose() => _client.close();
}

class _Resolved {
  _Resolved(this.edition, this.at);

  final DailyEdition edition;
  final DateTime at;

  bool isValidOn(DateTime today, DateTime now) {
    if (edition.freshness == DailyFreshness.today) {
      return edition.day == today;
    }
    return now.difference(at) < DailyContentResolver._staleRecheck;
  }
}

/// One resolver for the app, so the probe results are shared.
final dailyContentResolver = Provider<DailyContentResolver>((ref) {
  final resolver = DailyContentResolver();
  ref.onDispose(resolver.dispose);
  return resolver;
});
