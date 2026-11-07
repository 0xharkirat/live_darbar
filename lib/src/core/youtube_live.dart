/// Whether SGPC is streaming Sri Harmandir Sahib live on YouTube, and which
/// video the "Watch live on YouTube" row opens.
///
/// The row follows a checked answer. A GitHub Action asks YouTube every 5
/// minutes which of SGPC's streams are live, and publishes the result
/// ([YoutubeLiveCheck]). SGPC runs a kirtan video, a Hukamnama Katha video and
/// an audio-only stream, so [youtubeLiveLink] shows the row only for a video
/// stream, and opens that exact video. When the answer is missing, cannot be
/// read, or is too old ([YoutubeLiveCheck.isFreshAt]), the app falls back to
/// the timetable below: the times at which SGPC has gone live. The row shows
/// inside them and opens the channel's live page ([kYoutubeLiveUrl]). Outside
/// them it is hidden.
///
/// Facts, researched on 7 November 2026:
///
/// * The official channel is "SGPC, Sri Amritsar", @SGPCSriAmritsar. Its ID is
///   [kYoutubeChannelId]. Channels that copy it exist, so the app pins the ID
///   and never the handle or the name.
/// * [kYoutubeLiveUrl] opens the live video when a stream is on, and the
///   channel page when it is not. It can open the audio stream, which is why
///   it is only the fallback. On iPhone it opens in the YouTube app (a
///   universal link). On Android it is likely to open the app too.
/// * SGPC streams about 3 times a day. From 1 to 7 November 2026 the streams
///   ran 03:59 to 09:05, 12:30 to 14:21 and 17:00 to 18:55, India time. The
///   windows below are a little wider than that, so a stream that starts
///   early or runs late is still covered.
library;

import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/youtube_live_check.dart';

/// The ID of SGPC's official channel, "SGPC, Sri Amritsar" (@SGPCSriAmritsar).
const kYoutubeChannelId = 'UCYn6UEtQ771a_OWSiNBoG8w';

/// The channel's live page. It opens the live video when a stream is on, and
/// the channel page when it is not. It is the link of the timetable fallback,
/// and of a stream whose own link fails the check in [youtubeLiveLink].
const kYoutubeLiveUrl =
    'https://www.youtube.com/channel/$kYoutubeChannelId/live';

/// The start of every link to one YouTube video that the app opens.
const kYoutubeWatchPrefix = 'https://www.youtube.com/watch?v=';

/// The characters of a YouTube video ID: 11 of `A-Z a-z 0-9 - _`.
final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// One window of the day: from [start] up to, but not including, [end].
///
/// Both are the time since midnight in India, so 04:00 is `Duration(hours: 4)`.
typedef YoutubeWindow = ({Duration start, Duration end});

/// The windows in which a stream is likely to be on, in India time (UTC+5:30,
/// no daylight saving). They are the fallback for when there is no fresh
/// checked answer. They are in order, do not overlap, and all end before
/// midnight.
///
/// Seen on 1 to 7 November 2026: 03:59 to 09:05, 12:30 to 14:21 and 17:00 to
/// 18:55. The morning start is rounded to 04:00, and the midday and evening
/// ends are rounded up to 14:25 and 19:00.
const kYoutubeWindows = <YoutubeWindow>[
  (start: Duration(hours: 4), end: Duration(hours: 9, minutes: 5)),
  (
    start: Duration(hours: 12, minutes: 30),
    end: Duration(hours: 14, minutes: 25)
  ),
  (start: Duration(hours: 17), end: Duration(hours: 19)),
];

/// How long after midnight [now] is in India, whatever the zone of [now].
Duration _sinceIndiaMidnight(DateTime now) {
  final india = now.toUtc().add(kIndiaOffset);
  return india.difference(DateTime.utc(india.year, india.month, india.day));
}

/// Whether a stream is likely to be live at [now], by the timetable alone.
///
/// This is the fallback of [youtubeLiveLink], for when there is no fresh
/// checked answer. The answer depends on the instant alone. A listener in Sydney or in
/// Vancouver gets the same answer as one in Amritsar, because the windows are
/// in India time. A window includes its start and not its end.
bool isYoutubeLiveWindow(DateTime now) {
  final time = _sinceIndiaMidnight(now);
  return kYoutubeWindows.any((w) => time >= w.start && time < w.end);
}

/// How long from [now] until [isYoutubeLiveWindow] next changes its answer.
///
/// That is the next window start or end in India time. It is always more than
/// zero: at an edge, it counts to the one after. A timer set for this lets the
/// timetable fallback change at the edge, with no polling. See
/// [untilYoutubeLinkChanges] for the wait that also covers a checked answer.
Duration untilNextYoutubeChange(DateTime now) {
  final time = _sinceIndiaMidnight(now);
  for (final w in kYoutubeWindows) {
    if (time < w.start) return w.start - time;
    if (time < w.end) return w.end - time;
  }
  // After the last window: the first start of tomorrow.
  return const Duration(days: 1) + kYoutubeWindows.first.start - time;
}

/// What the "Watch live on YouTube" row does at [now], given the latest
/// [check]: the link a tap opens, or null when the row is hidden.
///
/// 1. A fresh [check] with a kirtan video stream live: the row shows, and the
///    link is that stream's. If there is no kirtan, a katha video stream
///    does the same. Audio and unknown kinds are not video.
/// 2. A fresh [check] with no video stream (nothing live, or audio only): the
///    row is hidden, even inside a timetable window.
/// 3. No [check], or one that is not fresh at [now]: the timetable. Inside a
///    window the row shows and opens [kYoutubeLiveUrl]. Outside, it is hidden.
///
/// The link of a stream is checked first: see [_streamLink].
String? youtubeLiveLink(DateTime now, YoutubeLiveCheck? check) {
  if (check != null && check.isFreshAt(now)) {
    final stream = check.video;
    return stream == null ? null : _streamLink(stream);
  }
  return isYoutubeLiveWindow(now) ? kYoutubeLiveUrl : null;
}

/// The link to open for [stream]: its own `url` when that is a watch link of
/// its own video, and [kYoutubeLiveUrl] otherwise.
///
/// The file comes from the network, so its link is not opened as it stands.
/// It must start with [kYoutubeWatchPrefix], the 11 characters after that
/// must be a video ID equal to the stream's `videoId`, and it may go on only
/// with more query (`&...`). A link to another host, a longer ID or a
/// fragment right after the ID fails. A stream is on, so the row stays and
/// opens the channel's live page instead.
String _streamLink(YoutubeStream stream) {
  final url = stream.url;
  final id = stream.videoId;
  if (!url.startsWith(kYoutubeWatchPrefix) || !_videoId.hasMatch(id)) {
    return kYoutubeLiveUrl;
  }
  final rest = url.substring(kYoutubeWatchPrefix.length);
  final matches = rest.startsWith(id) &&
      (rest.length == id.length || rest[id.length] == '&');
  return matches ? url : kYoutubeLiveUrl;
}

/// How long from [now] until [youtubeLiveLink] could next change its answer
/// with no new [check]: the next timetable edge, or the moment a fresh
/// [check] goes stale, whichever is first.
///
/// It is always more than zero. A timer set for this lets the row follow the
/// clock, with no polling. A new [check] is a separate event: the poll of the
/// published file.
Duration untilYoutubeLinkChanges(DateTime now, YoutubeLiveCheck? check) {
  final edge = untilNextYoutubeChange(now);
  final stale = check?.untilStale(now);
  return stale != null && stale < edge ? stale : edge;
}
