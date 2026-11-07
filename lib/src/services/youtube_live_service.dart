import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:live_darbar/src/models/youtube_live_check.dart';

/// Where the app reads which of SGPC's streams are live on YouTube: a file on
/// the `youtube-live` branch of this repository.
///
/// A GitHub Action asks YouTube every 5 minutes and publishes the answer
/// here. The file is shaped as [YoutubeLiveCheck] says. Like the Hukamnama
/// mirror (`kHukamnamaMirrorUrl` in `hukamnama_service.dart`),
/// `raw.githubusercontent.com` sends `access-control-allow-origin: *`, so the
/// web app can read it too, and the native apps need no key.
///
/// Overridable, so a build can be tried against a file on the developer's
/// machine:
///
///   flutter build web --dart-define=YOUTUBE_LIVE_URL=http://localhost:8141/live.json
const kYoutubeLiveCheckUrl = String.fromEnvironment(
  'YOUTUBE_LIVE_URL',
  defaultValue:
      'https://raw.githubusercontent.com/0xharkirat/live_darbar/youtube-live/live.json',
);

/// Fetches the published file of live YouTube streams.
///
/// The answer only refines a guess from the timetable (see
/// `core/youtube_live.dart`), so a fault must never reach the screen.
/// [fetch] never throws: an offline phone, a status other than 200, a request
/// that takes longer than [timeout] and a body that is not the file all give
/// null, which means "no answer".
///
/// The request is a plain GET with no custom header, so a browser needs no
/// preflight from `raw.githubusercontent.com`.
class YoutubeLiveService {
  YoutubeLiveService({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
    String url = kYoutubeLiveCheckUrl,
  })  : _client = client ?? http.Client(),
        _url = Uri.parse(url);

  final http.Client _client;
  final Uri _url;

  /// How long to wait for the whole response. The row already has an answer
  /// from the timetable, so the wait is short.
  final Duration timeout;

  /// The latest published answer, or null when there is none to use.
  Future<YoutubeLiveCheck?> fetch() async {
    try {
      final response = await _client.get(_url).timeout(timeout);
      if (response.statusCode != 200) return null;
      // The file is UTF-8 JSON. Decoding it here keeps a missing charset in
      // the headers from garbling a title.
      return YoutubeLiveCheck.tryParse(utf8.decode(response.bodyBytes));
    } catch (e) {
      if (!kReleaseMode) debugPrint('[youtube] live file not read: $e');
      return null;
    }
  }

  /// Closes the client. Call it when the service is no longer needed.
  void close() => _client.close();
}
