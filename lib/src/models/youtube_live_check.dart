import 'dart:convert';

/// What kind of stream an entry of the published file is.
enum YoutubeStreamKind {
  /// SGPC's live video of the kirtan at Sri Harmandir Sahib.
  kirtan,

  /// SGPC's live video of the Hukamnama Katha.
  katha,

  /// SGPC's audio-only stream. It has no picture, so the row ignores it.
  audio,

  /// A kind this app does not know. It counts as not video.
  unknown;

  /// Whether the stream has a picture, and so is worth a "Watch live" row.
  bool get isVideo => this == kirtan || this == katha;

  static YoutubeStreamKind _parse(Object? name) => switch (name) {
        'kirtan' => kirtan,
        'katha' => katha,
        'audio' => audio,
        _ => unknown,
      };
}

/// One stream that was live on YouTube when the file was made.
class YoutubeStream {
  const YoutubeStream({
    required this.videoId,
    required this.kind,
    required this.title,
    required this.url,
    this.startedAt,
  });

  /// The YouTube ID of the video: 11 characters of `A-Z a-z 0-9 - _`. The file
  /// is not trusted to keep to that, so a link is built only after a check
  /// (see `youtubeLiveLink`).
  final String videoId;

  final YoutubeStreamKind kind;

  /// The title on YouTube. For a person or a log, never for a decision.
  final String title;

  /// The watch link the file gives, `https://www.youtube.com/watch?v=<id>`.
  final String url;

  /// When the stream began, or null when the file does not say.
  final DateTime? startedAt;
}

/// The answer a GitHub Action publishes every 5 minutes: which of SGPC's
/// streams are live on YouTube now.
///
/// The file is `live.json` on the `youtube-live` branch of this repository
/// (see `kYoutubeLiveCheckUrl`):
///
/// ```json
/// {
///   "checkedAt": "2026-11-07T11:31:05Z",
///   "channelId": "UCYn6UEtQ771a_OWSiNBoG8w",
///   "live": [
///     {"videoId": "AbCdEfGhIjK", "kind": "kirtan", "title": "...",
///      "url": "https://www.youtube.com/watch?v=AbCdEfGhIjK",
///      "startedAt": "2026-11-07T11:30:00Z"}
///   ]
/// }
/// ```
///
/// `live` is empty when nothing is on, and `startedAt` can be absent. An
/// answer says nothing about the present once it is old, so check
/// [isFreshAt] before you use it.
class YoutubeLiveCheck {
  const YoutubeLiveCheck({
    required this.checkedAt,
    required this.live,
    this.channelId,
  });

  /// When the Action asked YouTube, always in UTC.
  final DateTime checkedAt;

  /// The channel the Action asked about, when the file says.
  final String? channelId;

  /// The streams that were live at [checkedAt]. Empty when none were.
  final List<YoutubeStream> live;

  /// How long after [checkedAt] the answer still counts as current.
  ///
  /// The Action runs every 5 minutes, but GitHub starts a scheduled job late
  /// when it is busy. 20 minutes covers a few missed runs and still drops an
  /// Action that has stopped.
  static const freshFor = Duration(minutes: 20);

  /// How far ahead of the phone's clock [checkedAt] may be. A phone clock that
  /// runs a little behind must not throw away a new answer.
  static const clockSkew = Duration(minutes: 5);

  /// Reads the text of the file, or returns null when it is not the file.
  ///
  /// It never throws. Anything that is not the shape of the file is "no
  /// answer", and the row then follows the timetable. A single broken entry
  /// spoils the whole file: skipping it could turn "a kirtan stream is on"
  /// into "only audio is on" and hide the row wrongly. An entry of an unknown
  /// kind is fine, as it only counts as not video.
  static YoutubeLiveCheck? tryParse(String body) {
    try {
      return fromJson(jsonDecode(body));
    } on FormatException {
      return null;
    }
  }

  /// Reads the decoded JSON of the file. Null when it is not the file.
  static YoutubeLiveCheck? fromJson(Object? json) {
    if (json is! Map) return null;
    final checkedAt = _utc(json['checkedAt']);
    final entries = json['live'];
    if (checkedAt == null || entries is! List) return null;

    final live = <YoutubeStream>[];
    for (final entry in entries) {
      if (entry is! Map) return null;
      final videoId = entry['videoId'];
      final url = entry['url'];
      if (videoId is! String || url is! String) return null;
      final title = entry['title'];
      live.add(
        YoutubeStream(
          videoId: videoId,
          kind: YoutubeStreamKind._parse(entry['kind']),
          title: title is String ? title : '',
          url: url,
          startedAt: _utc(entry['startedAt']),
        ),
      );
    }
    final channelId = json['channelId'];
    return YoutubeLiveCheck(
      checkedAt: checkedAt,
      channelId: channelId is String ? channelId : null,
      live: List.unmodifiable(live),
    );
  }

  /// A time in the file, in UTC. Null for anything else, including a time
  /// with no zone: it could be any zone, so it is not trusted.
  static DateTime? _utc(Object? text) {
    if (text is! String) return null;
    final time = DateTime.tryParse(text);
    return time != null && time.isUtc ? time : null;
  }

  /// Whether the answer still describes the present at [now].
  ///
  /// It does for [freshFor] after [checkedAt], and up to [clockSkew] before it.
  /// Both ends are inclusive.
  bool isFreshAt(DateTime now) {
    final age = now.toUtc().difference(checkedAt);
    return age <= freshFor && age >= -clockSkew;
  }

  /// How long from [now] until the answer stops being fresh, or null when it
  /// is not fresh at [now].
  ///
  /// A second is added so a timer set for this lands after the last fresh
  /// moment and not on it.
  Duration? untilStale(DateTime now) {
    if (!isFreshAt(now)) return null;
    final age = now.toUtc().difference(checkedAt);
    return freshFor - age + const Duration(seconds: 1);
  }

  /// The stream a "Watch live" row should open: the kirtan video, else the
  /// katha video, else null. Audio and unknown kinds never count.
  YoutubeStream? get video {
    for (final kind in const [
      YoutubeStreamKind.kirtan,
      YoutubeStreamKind.katha
    ]) {
      for (final stream in live) {
        if (stream.kind == kind) return stream;
      }
    }
    return null;
  }
}
