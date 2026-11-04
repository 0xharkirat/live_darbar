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

/// Where the web app reads the Hukamnama: a branch of this repository.
///
/// `hs.sgpc.net` sends no `Access-Control-Allow-Origin` header, on the call or
/// on its preflight, so a browser blocks the response. A CI job
/// (`.github/workflows/hukamnama-mirror.yml`) copies SGPC's answer to the
/// `hukamnama-data` branch. `raw.githubusercontent.com` serves it with
/// `access-control-allow-origin: *` and `cache-control: max-age=300`, checked
/// on 3 November 2026. The native apps do not use this.
///
/// The files are `<this>/hukamnama/YYYY-MM-DD.json`. Overridable, so a web
/// build can be tried against a folder on the developer's machine:
///
///   flutter build web --dart-define=HUKAMNAMA_MIRROR_URL=http://localhost:8141/mirror
const kHukamnamaMirrorUrl = String.fromEnvironment(
  'HUKAMNAMA_MIRROR_URL',
  defaultValue:
      'https://raw.githubusercontent.com/0xharkirat/live_darbar/hukamnama-data',
);

/// Fetches one day's Hukamnama as text from SGPC.
///
/// SGPC publishes the Hukamnama, and the app already plays its audio and shows
/// its PDF, so the text comes from the same place. SGPC states no terms or
/// costs for the feed. It is undocumented, though, and could change without
/// notice, which is why a response is checked in full before it is used.
///
/// ## The request
///
/// `POST https://hs.sgpc.net/hssearchhukmanamaTestCalender.php` with a form
/// body `selected_date=YYYY-MM-DD`. Checked against the live server on
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
/// The server sends no CORS header, so a browser cannot read its answer. On web
/// [fetch] never calls SGPC. It reads a copy of SGPC's answer from the mirror
/// ([kHukamnamaMirrorUrl]), one file for each day, and parses it with the same
/// code as the native answer. A file can also carry the optional `shabad` and
/// `lines` keys that the mirror adds from the Shabad OS database. They end up
/// in [Hukamnama.shabad], which is null when they are missing or cannot be
/// read, so they never make a day fail. The mirror only holds answers that
/// passed the checks of its script, so:
/// - a day with no file (HTTP 404) is a day not posted yet, as SGPC's own
///   `supported: false` is: [HukamnamaNotPublishedException];
/// - any other status is a fault: [HukamnamaException], so the controller's
///   retry and stale-text logic works as it does on native.
class HukamnamaService {
  HukamnamaService({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
    bool? isWeb,
    String mirrorUrl = kHukamnamaMirrorUrl,
  })  : _client = client ?? http.Client(),
        _isWeb = isWeb ?? (kIsWeb || kIsWasm),
        _mirrorUrl = mirrorUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final bool _isWeb;
  final String _mirrorUrl;

  /// How long to wait for the whole response. A request with no deadline can
  /// leave a screen on a spinner forever, so every request has one.
  final Duration timeout;

  /// The Hukamnama for [day], an SGPC day.
  ///
  /// Throws [HukamnamaNotPublishedException] when there is no text for the day,
  /// [TimeoutException] after [timeout], and [HukamnamaException] for any other
  /// answer it cannot use. A phone that is offline surfaces the client's own
  /// error (`SocketException` or `ClientException`).
  Future<Hukamnama> fetch(DateTime day) async {
    final want = DateTime.utc(day.year, day.month, day.day);
    final response = await (_isWeb ? _getFromMirror(want) : _postToSgpc(want))
        .timeout(timeout);

    // A file the mirror does not have is a day that is not posted yet.
    if (_isWeb && response.statusCode == 404) {
      throw HukamnamaNotPublishedException(want);
    }
    if (response.statusCode != 200) {
      throw HukamnamaException(
        'HTTP ${response.statusCode} from ${_isWeb ? 'the mirror' : 'SGPC'}.',
      );
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

  Future<http.Response> _postToSgpc(DateTime day) => _client.post(
        Uri.parse(kHukamnamaArchiveUrl),
        headers: const {'X-Requested-With': 'XMLHttpRequest'},
        body: {'selected_date': sgpcDayIso(day)},
      );

  /// A plain GET with no headers of our own, so the browser sends a simple
  /// request and no CORS preflight.
  Future<http.Response> _getFromMirror(DateTime day) => _client.get(
        Uri.parse('$_mirrorUrl/hukamnama/${sgpcDayIso(day)}.json'),
      );

  void close() => _client.close();
}
