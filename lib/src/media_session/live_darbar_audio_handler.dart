import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/media_session/media_catalog.dart';
import 'package:live_darbar/src/media_session/session_state.dart';
import 'package:live_darbar/src/media_session/voice_query.dart';

/// How far a fast forward jumps in a recording.
const kFastForwardInterval = Duration(seconds: 30);

/// How far a rewind jumps. Shorter, because the usual reason is to hear the
/// last sentence again.
const kRewindInterval = Duration(seconds: 15);

/// A prepare that no play followed is forgotten after this long.
const _preparedFor = Duration(seconds: 30);

/// Everything outside the app that controls playback: the notification, the
/// lock screen, a headset, Bluetooth, Android Auto and a voice assistant.
///
/// It owns no audio. [AudioController] still owns the player, the reconnects,
/// the quality tiers and every race fix in it, and the handler only translates.
/// Commands from the platform become calls on the controller, and what the
/// controller reports becomes the media session's state.
///
/// Two rules shape the translation.
///
/// **Live has no timeline.** Seek, fast forward, rewind and skip are for
/// recordings only. On live they do nothing and say nothing. The platform
/// always offers rewind and fast forward on a session, so a headset or a car
/// can send them at the live stream, and passing them on would seek a source
/// that cannot.
///
/// **The tree is small and fixed.** Three playable items, no folders. A voice
/// query picks one of them with [sourceForQuery], and live is the answer to
/// anything it does not understand.
class LiveDarbarAudioHandler extends BaseAudioHandler {
  LiveDarbarAudioHandler(
    this._controller, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _subscriptions
      ..add(_controller.playbackEventStream.listen((_) => _publish()))
      ..add(_controller.playStateStream.listen((_) => _publish()))
      ..add(_controller.liveStream.listen((_) => _publish()))
      ..add(_controller.sourceStream.listen((_) => _publish()));
    _publish();
    unawaited(_loadArtwork());
  }

  /// Starts the platform side and returns the handler that answers it.
  ///
  /// Call it once, before the first frame, so a command that woke the app (a
  /// notification button, a car, a voice assistant) finds a handler waiting.
  static Future<LiveDarbarAudioHandler> init(AudioController controller) {
    return AudioService.init(
      builder: () => LiveDarbarAudioHandler(controller),
      config: serviceConfig,
    );
  }

  /// How the Android service behaves. Public so a test can pin the two
  /// settings below, which a later edit could undo without any other test
  /// noticing.
  @visibleForTesting
  static const serviceConfig = AudioServiceConfig(
    // The id looks like a leftover from a demo, and it is one. Android
    // keys notification channels by id and never deletes an old one short
    // of an uninstall, so renaming it would leave every existing user
    // with two "Audio playback" entries in their notification settings.
    // The id is invisible to users; only the name shows.
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    // The service stays in the foreground through a pause. With the default,
    // a pause drops it to a background service, and a server that hangs up
    // on a paused live stream (after 45 to 90 s) makes audio_service stop the
    // service as well. The play that follows, after a phone call for example,
    // then has to start a foreground service from the background, which
    // Android 12 and later refuse with
    // ForegroundServiceStartNotAllowedException. The session ends on a
    // stop, and only then. See [isSessionEngaged].
    //
    // "Ongoing" needs the default behaviour: audio_service ignores it while
    // the service is in the foreground, and asserts if it is set otherwise.
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: false,
    androidNotificationIcon: 'drawable/ic_notification',
    // The paintings are 750 px wide. Notifications and cars need no more
    // than this, and a smaller bitmap crosses to the system more cheaply.
    artDownscaleWidth: 512,
    artDownscaleHeight: 512,
    fastForwardInterval: kFastForwardInterval,
    rewindInterval: kRewindInterval,
    // Android Auto reads these from the root and lays the tree out as a
    // list, which suits three rows with a title and an artist each.
    androidBrowsableRootExtras: {
      AndroidContentStyle.supportedKey: true,
      AndroidContentStyle.playableHintKey:
          AndroidContentStyle.listItemHintValue,
      AndroidContentStyle.browsableHintKey:
          AndroidContentStyle.listItemHintValue,
    },
  );

  final AudioController _controller;
  final DateTime Function() _now;
  final _subscriptions = <StreamSubscription<Object?>>[];

  Map<int, Uri> _art = const {};
  bool _engaged = false;
  bool _disposed = false;

  /// A source chosen by a prepare, waiting for the play that follows it.
  ({int index, DateTime at})? _prepared;

  // ---------------------------------------------------------------- publish

  /// Send the controller's state to the platform, if it changed in a way
  /// anyone can see.
  void _publish() {
    if (_disposed) return;
    final player = _controller.playerState;
    _engaged = isSessionEngaged(
      wasEngaged: _engaged,
      playerPlaying: player.playing,
      wantsPlayback: _controller.wantsPlayback,
      stopped: _controller.isStopped,
    );
    _publishItem();
    final next = buildPlaybackState(
      sourceIndex: _controller.sourceIndex,
      processing: player.processingState,
      playerPlaying: player.playing,
      wantsPlayback: _controller.wantsPlayback,
      engaged: _engaged,
      status: _controller.liveState.status,
      canSeek: _controller.canSeek,
      position: _controller.position,
      bufferedPosition: _controller.bufferedPosition,
    );
    if (isMeaningfulChange(playbackState.value, next)) {
      playbackState.add(next);
    }
  }

  /// Keep the current media item on the source being asked for, and give a
  /// recording its length once the player knows it.
  void _publishItem() {
    final index = _controller.sourceIndex;
    final item = MediaCatalog.item(
      index,
      artUri: _art[index],
      duration: _controller.canSeek ? _controller.duration : null,
    );
    final current = mediaItem.value;
    if (current != null &&
        current.id == item.id &&
        current.duration == item.duration &&
        current.artUri == item.artUri) {
      return;
    }
    mediaItem.add(item);
  }

  Future<void> _loadArtwork() async {
    try {
      _art = await _controller.artworkUris();
    } catch (e) {
      // No picture is better than no handler.
      if (!kReleaseMode) debugPrint('[session] artwork: $e');
    }
    _publish();
  }

  // ------------------------------------------------------------- transport

  @override
  Future<void> play() => _guard('play', () {
        final prepared = _takePrepared();
        return _started(
          prepared != null ? _controller.play(prepared) : _controller.resume(),
        );
      });

  /// Tell the platform that sound was asked for, now, and then wait for it.
  ///
  /// [started] is a call to the controller that has run up to its first
  /// await, so [AudioController.wantsPlayback] is already true. The platform
  /// still needs to hear it. A play that joins the warm-up load from launch
  /// emits nothing, and the player says nothing until that load is done. On a
  /// cold start from a Bluetooth button or Android Auto the first state is the
  /// one that makes audio_service call startForeground. Android allows 5 to
  /// 10 seconds between startForegroundService and startForeground, and a slow
  /// link can take the whole load to answer. So publish the state before the
  /// wait.
  Future<void> _started(Future<void> started) {
    _publish();
    return started;
  }

  @override
  Future<void> pause() => _guard('pause', () {
        _prepared = null;
        return _controller.pause();
      });

  @override
  Future<void> stop() => _guard('stop', () {
        _prepared = null;
        return _controller.stop();
      });

  @override
  Future<void> seek(Duration position) => _guard('seek', () async {
        if (!_controller.canSeek) return;
        await _controller.seek(_clamp(position));
      });

  @override
  Future<void> fastForward() => _jump(kFastForwardInterval);

  @override
  Future<void> rewind() => _jump(-kRewindInterval);

  // A headset's next and previous buttons, and a car's. A recording has no
  // other items to skip to, so they take the same jump as fast forward and
  // rewind, which is what podcast apps do. Live ignores them.
  @override
  Future<void> skipToNext() => fastForward();

  @override
  Future<void> skipToPrevious() => rewind();

  Future<void> _jump(Duration by) => _guard('jump', () async {
        if (!_controller.canSeek) return;
        await _controller.seek(_clamp(_controller.position + by));
      });

  Duration _clamp(Duration position) {
    final length = _controller.duration;
    if (position < Duration.zero) return Duration.zero;
    if (length != null && position > length) return length;
    return position;
  }

  // ------------------------------------------------------------ voice, ids

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) =>
      _playSource(sourceForQuery(query));

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) =>
      _playSource(sourceForMediaId(mediaId));

  // Some assistants prepare a source and then send a bare play. If the
  // prepare did nothing, that play would resume whatever was last, and
  // "play the Katha" would start live kirtan. So a prepare names the source,
  // and the next play starts it.
  @override
  Future<void> prepareFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async =>
      _prepare(sourceForQuery(query));

  @override
  Future<void> prepareFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async =>
      _prepare(sourceForMediaId(mediaId));

  void _prepare(int index) => _prepared = (index: index, at: _now());

  int? _takePrepared() {
    final prepared = _prepared;
    _prepared = null;
    if (prepared == null) return null;
    return _now().difference(prepared.at) <= _preparedFor
        ? prepared.index
        : null;
  }

  Future<void> _playSource(int index) => _guard('play source $index', () {
        _prepared = null;
        return _started(_controller.play(index));
      });

  // ----------------------------------------------------------------- browse

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final art = await _artwork();
    switch (parentMediaId) {
      case AudioService.browsableRootId:
        return MediaCatalog.items(art);
      case AudioService.recentRootId:
        // The row a resume button offers: what the listener asked for last.
        final index = _controller.sourceIndex;
        return [MediaCatalog.item(index, artUri: art[index])];
      default:
        // Nothing nests below the three items.
        return const [];
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async =>
      MediaCatalog.byId(mediaId, await _artwork());

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async =>
      // Only a query with a keyword in it finds anything. Playing from a
      // search is different: that still defaults to live.
      MediaCatalog.search(query, await _artwork());

  Future<Map<int, Uri>> _artwork() async {
    if (_art.isNotEmpty) return _art;
    try {
      _art = await _controller.artworkUris();
    } catch (_) {
      // Rows without pictures still work.
    }
    return _art;
  }

  // --------------------------------------------------------------- plumbing

  /// Run a command from the platform and keep its failure here.
  ///
  /// A throw would travel back over the platform channel as an error to a
  /// caller that cannot do anything with it: a headset, a car, an assistant.
  Future<void> _guard(String what, FutureOr<void> Function() command) async {
    try {
      await command();
    } catch (e, stack) {
      if (!kReleaseMode) debugPrint('[session] $what failed: $e\n$stack');
    }
  }

  /// Stop listening to the controller. The app never calls this, because the
  /// handler lives as long as the process does. Tests do.
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }
}
