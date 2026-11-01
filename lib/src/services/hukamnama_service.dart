import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';

/// The service did not give a usable Hukamnama.
class HukamnamaException implements Exception {
  const HukamnamaException(this.message);

  final String message;

  @override
  String toString() => 'HukamnamaException: $message';
}

/// The service is reachable and has no Hukamnama for that day yet.
///
/// The ordinary state for the first hours of each SGPC day, until the
/// Hukamnama is read and posted (about 05:30 IST). It is not a fault, and
/// asking again at once will not change the answer.
class HukamnamaNotPublishedException extends HukamnamaException {
  const HukamnamaNotPublishedException(this.day)
      : super('No Hukamnama is published for that day yet.');

  final DateTime day;
}

/// The text cannot be fetched on web.
///
/// `hs.sgpc.net` sends no `Access-Control-Allow-Origin` header, on the call or
/// on its preflight, so a browser blocks the response. The service fails at
/// once on web rather than after a request that cannot work. A screen should
/// show a link to [kHukamnamaSourceUrl] instead of the text.
class HukamnamaWebUnsupportedException extends HukamnamaException {
  const HukamnamaWebUnsupportedException()
      : super('SGPC does not allow a web page to fetch the Hukamnama.');
}

/// Fetches one day's Hukamnama as text from SGPC.
///
/// SGPC publishes the Hukamnama, and the app already plays its audio and shows
/// its PDF, so the text comes from the same place. SGPC states no terms or
/// costs for the feed. It is undocumented, though, and could change without
/// notice, which is why a response is checked in full before it is used.
///
/// ## The request
///
/// `POST https://hs.sgpc.net/hssearchhukmanamaTestCalender.php` (the same
/// endpoint `MukhwakController` uses for the PDF id) with a form body
/// `selected_date=YYYY-MM-DD`. Checked against the live server on
/// 2 November 2026:
/// - The header `X-Requested-With: XMLHttpRequest` is required. Without it the
///   server answers `200` with an empty `text/html` body, even for a day that
///   exists.
/// - The day is always sent explicitly, as the SGPC day. With no
///   `selected_date` the server answers with its own idea of the latest day.
/// - The answer is JSON with ASCII `\u` escapes and no charset, so it is
///   decoded as UTF-8 here and never trusted to the client's default.
///
/// ## The answers
///
/// - A day with a Hukamnama: `200`, `supported: true`, and the text. See
///   [Hukamnama.fromSgpc].
/// - A day with none, which includes a day not posted yet (tomorrow, or today
///   before about 05:30 IST) and a day before the archive starts (2003): `200`
///   and `{"supported":false,"hukamnama":{"date":"2026-11-03","message":
///   "No Hukamnama Available for this date."},"pdfFiles":[]}`, with the day
///   asked in `date`. That is [HukamnamaNotPublishedException].
/// - A malformed day (`garbage`, `2026-13-45`, an empty string) gets that same
///   answer. The service only sends real days, so it cannot tell the two apart
///   and does not need to.
/// - The status code never signals any of this, so it is not relied on.
///
/// ## Web
///
/// The server sends no CORS header, so [fetch] throws
/// [HukamnamaWebUnsupportedException] on web before it sends anything.
class HukamnamaService {
  HukamnamaService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
    bool? isWeb,
  })  : _client = client ?? http.Client(),
        _isWeb = isWeb ?? (kIsWeb || kIsWasm);

  final http.Client _client;
  final bool _isWeb;

  /// How long to wait for the whole response. A request with no deadline can
  /// leave a screen on a spinner forever, so every request has one.
  final Duration timeout;

  /// Whether [fetch] can work on this platform. False on web.
  bool get isSupported => !_isWeb;

  /// The Hukamnama for [day], an SGPC day.
  ///
  /// Throws [HukamnamaWebUnsupportedException] on web,
  /// [HukamnamaNotPublishedException] when SGPC has no text for the day,
  /// [TimeoutException] after [timeout], and [HukamnamaException] for any other
  /// answer it cannot use. A phone that is offline surfaces the client's own
  /// error (`SocketException` or `ClientException`).
  Future<Hukamnama> fetch(DateTime day) async {
    if (_isWeb) throw const HukamnamaWebUnsupportedException();

    final want = DateTime.utc(day.year, day.month, day.day);
    final response = await _client
        .post(
          Uri.parse(kHukamnamaArchiveUrl),
          headers: const {'X-Requested-With': 'XMLHttpRequest'},
          body: {'selected_date': sgpcDayIso(want)},
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw HukamnamaException('HTTP ${response.statusCode} from SGPC.');
    }

    final Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('The response is not a JSON object.');
      }
      body = decoded;
    } on FormatException catch (e) {
      throw HukamnamaException('Unreadable response: ${e.message}');
    }

    // Only an explicit false is "not posted". A body with no `supported` at
    // all is not SGPC's answer, so it falls through to the parser and fails.
    if (body['supported'] == false) throw HukamnamaNotPublishedException(want);

    final Hukamnama parsed;
    try {
      parsed = Hukamnama.fromSgpc(body);
    } on FormatException catch (e) {
      throw HukamnamaException('Unreadable response: ${e.message}');
    }

    // Never relabel. If the service answers with a different day from the one
    // asked for, the text is not what was requested, and showing it under the
    // requested day would be exactly the stale-as-today mistake.
    if (parsed.date != want) {
      throw HukamnamaException(
        'Asked for ${sgpcDayIso(want)} but got ${sgpcDayIso(parsed.date)}.',
      );
    }
    return parsed;
  }

  void close() => _client.close();
}
