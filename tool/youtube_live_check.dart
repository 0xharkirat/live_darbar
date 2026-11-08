// Checks which of SGPC's YouTube streams are live now, and writes the answer
// for the app: live.json, with the video streams first.
//
// Why: SGPC streams Sri Harmandir Sahib on YouTube about 5 times a day: 3
// kirtan videos, 1 Hukamnama Katha video, and an audio stream that fills the
// gaps between the videos. The app guessed from a timetable and opened the
// channel's /live page, which can open the audio stream. Hark, 7 November
// 2026: "a correct live stream link for video only, not audio only".
//
// How: the channel's streams page marks each live stream LIVE, and its /live
// page names 1 of them. The tool opens each of those streams' own page and
// believes it only when YouTube says, for that video, that it plays, that it
// is SGPC's own channel, and that it is live now. The title says the kind:
// "(Audio)" is audio only, "Katha" is the Hukamnama Katha, and the rest is
// kirtan.
//
// It never writes "nothing is live" when it could not check: a page it cannot
// read, or a stream YouTube will not show, is an error, and nothing is
// written. The file then goes stale, and the app falls back to its
// timetable (lib/src/core/youtube_live.dart).
//
// Run by .github/workflows/youtube-live.yml every 5 minutes:
//
//   dart tool/youtube_live_check.dart --out DIR
//
// It writes DIR/live.json, and adds a line to DIR/events.jsonl each time a
// stream starts or ends, so the record of what was live, and when, builds up.
// It imports only `dart:` libraries, so it runs with plain `dart`.

import 'dart:convert';
import 'dart:io';

/// The ID of SGPC's official channel, "SGPC, Sri Amritsar" (@SGPCSriAmritsar).
/// Channels that copy it exist, so only this ID is believed.
const kSgpcChannelId = 'UCYn6UEtQ771a_OWSiNBoG8w';

/// What a live stream carries.
enum StreamKind {
  /// Kirtan from Sri Harmandir Sahib, with video.
  kirtan,

  /// The Hukamnama Katha from Gurdwara Sri Manji Sahib, with video.
  katha,

  /// Audio only, with a still picture.
  audio,
}

/// The kind of a stream, from its title. SGPC names the audio stream
/// "Official SGPC LIVE (Audio) | Gurbani Kirtan | ..." and the katha
/// "Hukamnama Katha (discourse) Gurdwara Sri Manji Sahib ...".
StreamKind kindOf(String title) {
  if (RegExp(r'\baudio\b', caseSensitive: false).hasMatch(title)) {
    return StreamKind.audio;
  }
  if (RegExp(r'\bkatha\b', caseSensitive: false).hasMatch(title)) {
    return StreamKind.katha;
  }
  return StreamKind.kirtan;
}

/// A page that is not what the tool expects. The run fails, and nothing is
/// written.
class PageError implements Exception {
  PageError(this.message);
  final String message;
  @override
  String toString() => 'PageError: $message';
}

final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// The JSON that a YouTube page sets in `var [name] = {...};`.
Map<String, Object?> _pageJson(String html, String name) {
  final start = RegExp('var $name = ').firstMatch(html);
  if (start == null) throw PageError('The page has no $name.');
  // The object ends at the `;` after its last brace. Decoding from the start
  // and growing to each `};` finds it without a JSON scanner.
  var end = html.indexOf('};', start.end);
  while (end != -1) {
    try {
      return jsonDecode(html.substring(start.end, end + 1))
          as Map<String, Object?>;
    } on FormatException {
      end = html.indexOf('};', end + 2);
    }
  }
  throw PageError('The $name on the page does not end.');
}

/// The IDs of the streams that the channel's streams page marks LIVE, in
/// page order.
///
/// Throws [PageError] when the page has no list of streams at all: then the
/// page has changed, and "no live stream" would be a guess.
List<String> liveIdsOnStreamsPage(String html) {
  final data = _pageJson(html, 'ytInitialData');
  final ids = <String>[];
  var items = 0;
  void walk(Object? node) {
    if (node is Map) {
      final lockup = node['lockupViewModel'];
      if (lockup is Map) {
        items++;
        final id = lockup['contentId'];
        if (id is String && _videoId.hasMatch(id) && _marksLive(lockup)) {
          ids.add(id);
        }
        return;
      }
      final video = node['videoRenderer'];
      if (video is Map) {
        items++;
        final id = video['videoId'];
        if (id is String && _videoId.hasMatch(id) && _marksLive(video)) {
          ids.add(id);
        }
        return;
      }
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  walk(data);
  if (items == 0) throw PageError('The streams page lists no streams.');
  return ids;
}

/// Whether a stream's tile carries the LIVE badge.
bool _marksLive(Map<Object?, Object?> tile) {
  var live = false;
  void walk(Object? node) {
    if (live) return;
    if (node is Map) {
      final style = node['badgeStyle'] ?? node['style'];
      if (style is String && style.endsWith('_LIVE') ||
          style == 'BADGE_STYLE_TYPE_LIVE_NOW') {
        live = true;
        return;
      }
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  walk(tile);
  return live;
}

/// The video that the channel's /live page shows, from its canonical link,
/// or null when it shows the channel instead.
String? idOnLivePage(String html) {
  final canonical = RegExp(
    r'<link rel="canonical" href="https://www\.youtube\.com/watch\?v=([A-Za-z0-9_-]{11})"',
  ).firstMatch(html);
  return canonical?.group(1);
}

/// A stream that its own page confirms is live on SGPC's channel.
class LiveStream {
  LiveStream({
    required this.videoId,
    required this.title,
    required this.kind,
    this.startedAt,
  });

  final String videoId;
  final String title;
  final StreamKind kind;
  final DateTime? startedAt;

  String get url => 'https://www.youtube.com/watch?v=$videoId';

  Map<String, Object?> toJson() => {
        'videoId': videoId,
        'kind': kind.name,
        'title': title,
        'url': url,
        if (startedAt != null) 'startedAt': _iso(startedAt!),
      };
}

/// What a stream's own page says about it: the stream when it is live on
/// SGPC's channel now, or null when it is not live (any more).
///
/// Throws [PageError] when the page cannot say: YouTube did not show the
/// video (a sign-in or robot check, for example), or the page is not about
/// [videoId]. A stream on another channel is an error too, because the
/// streams page of SGPC's channel named it.
LiveStream? checkWatchPage(String html, String videoId) {
  final player = _pageJson(html, 'ytInitialPlayerResponse');
  final status = (player['playabilityStatus'] as Map?)?['status'];
  final details = player['videoDetails'];
  if (status != 'OK' || details is! Map) {
    throw PageError('YouTube did not show $videoId: status $status.');
  }
  if (details['videoId'] != videoId) {
    throw PageError('The page for $videoId is about ${details['videoId']}.');
  }
  if (details['channelId'] != kSgpcChannelId) {
    throw PageError('$videoId is on ${details['channelId']}, not SGPC.');
  }
  final broadcast =
      ((player['microformat'] as Map?)?['playerMicroformatRenderer']
          as Map?)?['liveBroadcastDetails'] as Map?;
  final live = details['isLive'] == true && broadcast?['isLiveNow'] != false;
  if (!live) return null;
  final title = details['title'];
  if (title is! String || title.trim().isEmpty) {
    throw PageError('$videoId has no title.');
  }
  final start = broadcast?['startTimestamp'];
  return LiveStream(
    videoId: videoId,
    title: title.trim(),
    kind: kindOf(title),
    startedAt: start is String ? DateTime.tryParse(start)?.toUtc() : null,
  );
}

/// live.json: when the check ran, and the live streams, kirtan first, then
/// katha, then audio.
Map<String, Object?> liveJson(List<LiveStream> live, DateTime checkedAt) {
  final sorted = [...live]
    ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
  return {
    'checkedAt': _iso(checkedAt),
    'channelId': kSgpcChannelId,
    'live': [for (final s in sorted) s.toJson()],
  };
}

/// The lines for events.jsonl: 1 for each stream that started or ended since
/// [before], the last live.json.
List<Map<String, Object?>> events(
  Map<String, Object?>? before,
  List<LiveStream> now,
  DateTime at,
) {
  final was = <String, Map<Object?, Object?>>{
    for (final s in (before?['live'] as List?) ?? const [])
      if (s is Map && s['videoId'] is String) s['videoId'] as String: s,
  };
  final ids = {for (final s in now) s.videoId};
  return [
    for (final s in now)
      if (!was.containsKey(s.videoId))
        {'at': _iso(at), 'event': 'start', ...s.toJson()},
    for (final MapEntry(:key, :value) in was.entries)
      if (!ids.contains(key))
        {
          'at': _iso(at),
          'event': 'end',
          'videoId': key,
          'kind': value['kind'],
          'title': value['title'],
        },
  ];
}

String _iso(DateTime t) =>
    '${t.toUtc().toIso8601String().split('.').first.replaceAll('Z', '')}Z';

Future<String> _get(HttpClient client, String url) async {
  final request = await client.getUrl(Uri.parse(url));
  request.headers
    ..set(HttpHeaders.acceptLanguageHeader, 'en')
    // Declines YouTube's cookie banner, which some regions show first.
    ..set(HttpHeaders.cookieHeader, 'SOCS=CAI');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw PageError('$url answered ${response.statusCode}.');
  }
  return body;
}

Future<void> main(List<String> args) async {
  if (args.length != 2 || args[0] != '--out') {
    stderr.writeln('usage: dart tool/youtube_live_check.dart --out DIR');
    exitCode = 64;
    return;
  }
  final out = Directory(args[1]);
  final client = HttpClient()
    ..userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/130.0 Safari/537.36'
    ..connectionTimeout = const Duration(seconds: 20);
  try {
    const channel = 'https://www.youtube.com/channel/$kSgpcChannelId';
    final ids = liveIdsOnStreamsPage(await _get(client, '$channel/streams'));
    // The /live page is a second opinion. When it shows a stream that the
    // streams page did not mark, the badge has changed shape, and the page's
    // own check below still decides.
    final fromLive = idOnLivePage(await _get(client, '$channel/live'));
    if (fromLive != null && !ids.contains(fromLive)) ids.add(fromLive);

    final live = <LiveStream>[];
    for (final id in ids.take(6)) {
      final stream = checkWatchPage(
        await _get(client, 'https://www.youtube.com/watch?v=$id'),
        id,
      );
      stdout.writeln(stream == null
          ? '$id: not live'
          : '$id: live, ${stream.kind.name}, "${stream.title}"');
      if (stream != null) live.add(stream);
    }

    final now = DateTime.now().toUtc();
    final file = File('${out.path}/live.json');
    Map<String, Object?>? before;
    if (file.existsSync()) {
      try {
        before = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      } on FormatException {
        before = null;
      }
    }
    final lines = events(before, live, now);
    out.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(liveJson(live, now))}\n',
    );
    if (lines.isNotEmpty) {
      File('${out.path}/events.jsonl').writeAsStringSync(
        lines.map((l) => '${jsonEncode(l)}\n').join(),
        mode: FileMode.append,
      );
    }
    stdout.writeln(
        'Live: ${live.isEmpty ? 'nothing' : live.map((s) => s.kind.name).join(', ')}. '
        '${lines.length} start or end events.');
  } on PageError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } on IOException catch (e) {
    stderr.writeln('Could not reach YouTube: $e');
    exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
