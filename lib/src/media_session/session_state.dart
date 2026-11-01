import 'package:audio_service/audio_service.dart'
    show AudioProcessingState, MediaAction, MediaControl, PlaybackState;
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/source_index.dart';

/// Turns what the player is doing into what the media session says.
///
/// These are plain functions of plain values, so each rule can be tested
/// without a player, a platform channel or a phone.

/// Whether the media session has anything to show yet.
///
/// The player loads the live stream at launch, so that the first tap is
/// instant. A session that mirrored that would raise a notification, and a
/// car would list a paused stream, for somebody who only opened the app. So
/// the session stays idle until sound has been asked for, and then stays
/// engaged through pauses, so the notification is still there to resume from.
///
/// It lets go on a stop ([stopped]), and on nothing else.
///
/// A paused live stream is dropped by the server after 45 to 90 seconds, and
/// the player then goes idle. That is not a stop. An idle session makes
/// audio_service end the foreground service, and the play that follows a phone
/// call would have to start a new one from the background, which Android 12
/// and later refuse. So a drop while paused keeps the session, with a play
/// button that reconnects. See [buildPlaybackState].
bool isSessionEngaged({
  required bool wasEngaged,
  required bool playerPlaying,
  required bool wantsPlayback,
  required bool stopped,
}) {
  if (wantsPlayback || playerPlaying) return true;
  if (stopped) return false;
  return wasEngaged;
}

/// The media session's state for the player right now.
///
/// [sourceIndex] is the source the listener asked for, and [canSeek] says
/// whether it is a recording that is loaded and has a length. Live has
/// neither a length nor a position to seek to, so it gets no seek bar, no
/// fast forward and no rewind in the controls.
///
/// A reconnecting stream is never reported as an error. `error` makes the
/// platform drop the foreground service, and the controller is still trying.
/// Dropping it lets Android freeze the app in the middle of the retry.
PlaybackState buildPlaybackState({
  required int sourceIndex,
  required ProcessingState processing,
  required bool playerPlaying,
  required bool wantsPlayback,
  required bool engaged,
  required LiveStatus status,
  required bool canSeek,
  Duration position = Duration.zero,
  Duration bufferedPosition = Duration.zero,
  DateTime? updateTime,
}) {
  if (!engaged) return PlaybackState(updateTime: updateTime);

  final isLive = sourceIndex == kLiveIndex;
  final playing = wantsPlayback || playerPlaying;
  final processingState = _processingState(
    processing: processing,
    wantsPlayback: wantsPlayback,
    status: status,
  );
  // While a source loads, the player still reports the one before it. Its
  // position belongs to that source, so do not pass it on as this one's.
  final loading = processingState == AudioProcessingState.loading;

  return PlaybackState(
    processingState: processingState,
    playing: playing,
    controls: sessionControls(isLive: isLive, playing: playing),
    androidCompactActionIndices: isLive ? const [0, 1] : const [0, 1, 2],
    systemActions: {
      MediaAction.stop,
      // The seek bar. It is the one action that changes how a notification
      // looks, and it makes no sense on a stream with no length.
      if (!isLive && canSeek) MediaAction.seek,
    },
    // A live stream's position only counts the time since the connection
    // opened. Reporting it would look like a seek every time it reconnects.
    updatePosition: isLive || loading ? Duration.zero : position,
    bufferedPosition: isLive || loading ? Duration.zero : bufferedPosition,
    updateTime: updateTime,
  );
}

AudioProcessingState _processingState({
  required ProcessingState processing,
  required bool wantsPlayback,
  required LiveStatus status,
}) {
  // Every failure is a retry that is under way, so call it what it is.
  if (status == LiveStatus.failed) return AudioProcessingState.buffering;
  // A new source is opening. Until the player says so itself, it still
  // reports the one before it, and that would read as sound already playing.
  if (wantsPlayback && status == LiveStatus.connecting) {
    return AudioProcessingState.loading;
  }
  switch (processing) {
    case ProcessingState.idle:
      // Between a tap and the first byte the player is still idle, and a
      // voice assistant waits for anything but idle before it believes us.
      //
      // Idle with nobody asking for sound, in a session that is still
      // engaged, is a paused stream that the server dropped. It is paused,
      // not stopped: report "ready" with a play button. Reporting idle would
      // make audio_service end the foreground service. Only a stop does that,
      // and a stop is not engaged, so it never gets here.
      return wantsPlayback
          ? AudioProcessingState.loading
          : AudioProcessingState.ready;
    case ProcessingState.loading:
      return AudioProcessingState.loading;
    case ProcessingState.buffering:
      return AudioProcessingState.buffering;
    case ProcessingState.ready:
      return AudioProcessingState.ready;
    case ProcessingState.completed:
      return AudioProcessingState.completed;
  }
}

/// The buttons for the notification and the car.
///
/// Live offers play or pause and stop. A recording adds a jump back and a
/// jump forward around the play button. The live stream has no timeline, so
/// it gets neither.
List<MediaControl> sessionControls({
  required bool isLive,
  required bool playing,
}) {
  final playOrPause = playing ? MediaControl.pause : MediaControl.play;
  return isLive
      ? [playOrPause, MediaControl.stop]
      : [
          MediaControl.rewind,
          playOrPause,
          MediaControl.fastForward,
          MediaControl.stop,
        ];
}

/// Whether [next] differs from [previous] enough to send to the platform.
///
/// The player reports a new buffered position about once a second, and
/// every state sent crosses to the native service and rebuilds the
/// notification. Only a change that someone can see or press is worth that.
/// A position counts when it jumps away from where [previous] expected it,
/// which is what a seek looks like.
bool isMeaningfulChange(PlaybackState previous, PlaybackState next) {
  if (previous.processingState != next.processingState) return true;
  if (previous.playing != next.playing) return true;
  if (previous.errorMessage != next.errorMessage) return true;
  if (!_sameActions(previous, next)) return true;
  final drift = (next.updatePosition - previous.position).abs();
  return drift > const Duration(seconds: 2);
}

bool _sameActions(PlaybackState a, PlaybackState b) {
  if (a.controls.length != b.controls.length) return false;
  for (var i = 0; i < a.controls.length; i++) {
    if (a.controls[i] != b.controls[i]) return false;
  }
  return a.systemActions.length == b.systemActions.length &&
      a.systemActions.containsAll(b.systemActions);
}
