import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/source.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:rxdart/rxdart.dart';

/// Index of the live kirtan stream in the source list.
const kLiveIndex = 0;
const kMukhwakIndex = 1;
const kKathaIndex = 2;

/// Artwork for the lock screen and notification.
///
/// Pinned to `main` rather than the old `audio-controller` feature branch,
/// which could be deleted at any time and would take the artwork with it.
/// Serving this from the bundled asset instead would remove the network
/// dependency entirely, but that needs the image copied to a real file first,
/// because `MediaItem.artUri` cannot address a Flutter asset.
const _kArtUrl =
    'https://raw.githubusercontent.com/0xharkirat/live_darbar/refs/heads/main/assets/images/splash_logo.png';

/// Owns the player and everything about keeping the live stream alive.
///
/// Three ideas run through this class.
///
/// **The connection is precious.** Opening the live stream costs about 1.6
/// seconds, almost all of it server think-time we cannot influence. So the
/// stream is opened once at startup and then reused. Pressing play on an
/// already-loaded source must not reopen it, which is exactly the bug the old
/// code had: `play()` called `setAudioSource` unconditionally and threw away a
/// perfectly warm connection every single time.
///
/// **Failure is normal.** A phone changes networks, a mount restarts, a
/// captive portal blocks port 7339. None of that should end in a dead player
/// and an unlabelled refresh icon, so failures reconnect on a backoff and drop
/// to the other tier when one tier keeps refusing.
///
/// **Being behind live is a state, not an error.** Pausing does not stop the
/// download, so the playhead falls behind by however long you paused. That is
/// worth reporting and offering to fix, not worth silently reconnecting over.
class AudioController {
  AudioController(this._player) {
    _quality = StreamQuality.initial;
    _live.add(LivePlaybackState(quality: _quality));
    _attachListeners();
    unawaited(_warmUp());
  }

  final AudioPlayer _player;

  /// Backoff schedule for reconnects, in order. The last entry repeats.
  static const _backoff = <Duration>[
    Duration(milliseconds: 500),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
  ];

  /// Consecutive failures on one tier before trying the other one.
  ///
  /// Two rather than one because the first failure is usually transient and
  /// switching tier costs a third of the bitrate.
  static const _failuresBeforeTierSwitch = 2;

  /// A pause longer than this means the connection is probably gone.
  ///
  /// `maxBufferDuration` is 30 s below, and once the player stops reading,
  /// Icecast decides we are a slow client and drops us. So beyond roughly that
  /// window a resume has to reconnect whether the listener asked for it or not.
  static const _staleAfter = Duration(seconds: 45);

  late StreamQuality _quality;

  final _live = BehaviorSubject<LivePlaybackState>.seeded(
    const LivePlaybackState(),
  );

  /// Index currently handed to the player, or -1 when nothing is loaded.
  int _loadedIndex = -1;

  /// What the listener last asked for, kept across reconnects so that a
  /// recovery resumes playback rather than leaving them staring at a play
  /// button they already pressed.
  bool _wantsPlayback = false;

  /// False between loading a source and the first play on it.
  ///
  /// Distinguishes "resuming my own pause" from "pressing play for the first
  /// time on a connection that has been quietly buffering since launch", which
  /// want opposite things. See [_shouldReopenLive].
  bool _playedSinceLoad = false;

  DateTime? _pausedAt;

  /// Times the only number that matters: tap to sound.
  ///
  /// Started when playback is requested and read once the player reports it is
  /// actually playing. Logged outside release builds so the latency work can
  /// be checked on a real device instead of argued about.
  Stopwatch? _tapToSound;

  /// A load already running, so a second caller joins instead of restarting.
  Future<bool>? _inFlightLoad;
  int _inFlightIndex = -1;

  int _failures = 0;
  Timer? _reconnectTimer;
  Timer? _driftTimer;
  StreamSubscription<PlayerException>? _errorSub;
  StreamSubscription<PlayerState>? _stateSub;
  Stream<AudioProgressState>? _progressStream;
  bool _disposed = false;

  // ---------------------------------------------------------------- sources

  MediaItem _tag(String id, String title) => MediaItem(
        id: id,
        title: title,
        artUri: Uri.parse(_kArtUrl),
      );

  AudioSource _sourceFor(int index) {
    switch (index) {
      case kLiveIndex:
        return AudioSource.uri(
          Uri.parse(_quality.url),
          tag: _tag('0', 'Live Kirtan'),
        );
      case kMukhwakIndex:
        return AudioSource.uri(
          Uri.parse(kMukhWakUrl),
          tag: _tag('1', 'Mukhwak'),
        );
      case kKathaIndex:
        return AudioSource.uri(
          Uri.parse(kMukhwakKathaUrl),
          tag: _tag('2', 'Mukhwak Katha'),
        );
      default:
        throw ArgumentError.value(index, 'index', 'no such audio source');
    }
  }

  // ------------------------------------------------------------- public API

  Stream<LivePlaybackState> get liveStream => _live.stream;

  LivePlaybackState get liveState => _live.value;

  StreamQuality get quality => _quality;

  /// Start, or resume, the source at [index].
  ///
  /// The whole point of this method is what it does *not* do: if the source is
  /// already loaded it plays straight from the buffer rather than reopening
  /// the connection. On the common path, open the app and tap play, that is
  /// the difference between instant sound and a second and a half of nothing.
  Future<void> play([int index = kLiveIndex]) async {
    // Started here rather than next to `_player.play()` so that it measures
    // what the listener experiences. Any reconnect below happens on their
    // time, and a timer that skipped it would report zero for exactly the
    // case worth measuring.
    _tapToSound = Stopwatch()..start();
    _wantsPlayback = true;
    _cancelReconnect();

    final needsLoad = _loadedIndex != index || _isDead;
    if (needsLoad) {
      // Switching away from a failed attempt is a fresh start, so go back to
      // the preferred tier rather than staying stuck on a fallback forever.
      if (_loadedIndex != index) {
        _quality = StreamQuality.initial;
        _failures = 0;
      }
      final ok = await _load(index);
      if (!ok) return;
    } else if (index == kLiveIndex && _shouldReopenLive) {
      final ok = await _load(index);
      if (!ok) return;
    }

    _pausedAt = null;
    _playedSinceLoad = true;
    unawaited(_player.play());
  }

  /// Resume whatever is loaded, without changing source.
  Future<void> resume() => play(_loadedIndex < 0 ? kLiveIndex : _loadedIndex);

  Future<void> pause() async {
    _wantsPlayback = false;
    _pausedAt = DateTime.now();
    await _player.pause();
    _emit(status: LiveStatus.paused);
  }

  Future<void> stop() async {
    _wantsPlayback = false;
    _cancelReconnect();
    await _player.stop();
    await _player.seek(Duration.zero);
    _emit(status: LiveStatus.idle, behindLive: Duration.zero);
  }

  Future<void> seek(Duration duration) => _player.seek(duration);

  /// Jump back to the live edge.
  ///
  /// There is no cheaper way to do this. An Icecast stream has no duration and
  /// no seekable index, so "skip to live" can only mean closing the connection
  /// and opening a new one, which is why it costs the same second and a half
  /// as a cold start and why it is offered rather than done automatically.
  Future<void> skipToLive() async {
    if (_loadedIndex != kLiveIndex) return;
    _wantsPlayback = true;
    final ok = await _load(kLiveIndex, force: true);
    if (ok) unawaited(_player.play());
  }

  /// Act on the network coming back, without waiting out the backoff.
  ///
  /// Backoff is the right behaviour when we cannot tell why a connection
  /// failed, but once the OS says the radio is back there is no reason to sit
  /// out the remaining twenty seconds. Two cases matter and they want
  /// different things: somebody is waiting on playback, so reconnect and
  /// resume; or nothing is loaded and nobody is waiting, so quietly warm up
  /// again so the next tap is still instant.
  Future<void> onNetworkRestored() async {
    if (_disposed) return;
    if (_wantsPlayback) {
      _cancelReconnect();
      _failures = 0;
      _quality = StreamQuality.initial;
      final ok = await _load(
        _loadedIndex < 0 ? kLiveIndex : _loadedIndex,
        force: true,
      );
      if (ok) unawaited(_player.play());
    } else if (_loadedIndex < 0) {
      unawaited(_warmUp());
    }
  }

  /// Switch tier because the listener asked, not because something broke.
  Future<void> setQuality(StreamQuality quality) async {
    if (quality == _quality) return;
    _quality = quality;
    _failures = 0;
    _emit(quality: quality);
    if (_loadedIndex != kLiveIndex) return;
    final ok = await _load(kLiveIndex);
    if (ok && _wantsPlayback) unawaited(_player.play());
  }

  // ------------------------------------------------------------- internals

  bool get _isDead {
    final s = _player.processingState;
    return s == ProcessingState.idle || s == ProcessingState.completed;
  }

  Duration get _drift {
    final gap = _player.bufferedPosition - _player.position;
    return gap.isNegative ? Duration.zero : gap;
  }

  /// Whether to throw away the open connection and reopen at the live edge.
  ///
  /// This is the one place the warm-up strategy has to be honest about its
  /// cost. Preloading at launch means the buffer keeps filling while the app
  /// sits on the home screen, so somebody who opens the app, reads for a
  /// minute and then presses play would otherwise start a minute behind the
  /// broadcast: instant, but stale. They never paused anything, so that would
  /// read as a bug rather than a choice.
  ///
  /// Resuming their own pause is different. There the drift is self-inflicted
  /// and obvious, instant resume is what they want, and [LiveStatusWidget]
  /// offers the live edge rather than taking it.
  ///
  /// So: reopen when the *first* play after loading is already well behind,
  /// or when a pause has run long enough that the server has probably hung up
  /// on us anyway.
  bool get _shouldReopenLive {
    if (!_playedSinceLoad) {
      return _drift > LivePlaybackState.behindLiveThreshold;
    }
    final at = _pausedAt;
    return at != null && DateTime.now().difference(at) > _staleAfter;
  }

  /// Open the live stream at startup so the first tap has nothing to wait for.
  ///
  /// This is the whole latency win, and it is not free: it downloads up to
  /// `maxBufferDuration` of audio, around 700 KB, for someone who might never
  /// press play. That is a fair trade for an app whose one purpose is the
  /// button they opened it to press, but it is a trade, so the failure path
  /// deliberately does not retry. See [_onFailure].
  Future<void> _warmUp() async {
    await _load(kLiveIndex);
  }

  /// Point the player at [index], joining a load already in flight for it.
  ///
  /// The joining matters more than it looks. Warm-up starts at launch and
  /// takes about a second and a half, so anyone who taps play quickly arrives
  /// while it is still running. Without this, that tap called `setAudioSource`
  /// a second time, which tears down the first connection and starts over:
  /// tapping sooner made playback start later. Measured at 1441 ms on the
  /// emulator before the fix, against 0 ms once the warm-up had finished.
  ///
  /// [force] is for the cases that genuinely want a new connection even though
  /// one is open: jumping to the live edge, and switching tier.
  Future<bool> _load(int index, {bool force = false}) {
    final existing = _inFlightLoad;
    if (!force && existing != null && _inFlightIndex == index) return existing;

    final future = _performLoad(index);
    _inFlightLoad = future;
    _inFlightIndex = index;
    future.whenComplete(() {
      if (identical(_inFlightLoad, future)) {
        _inFlightLoad = null;
        _inFlightIndex = -1;
      }
    });
    return future;
  }

  /// Returns false if it failed, having already scheduled a retry.
  Future<bool> _performLoad(int index) async {
    if (_disposed) return false;
    _emit(
      status: LiveStatus.connecting,
      clearError: true,
      behindLive: Duration.zero,
      isLiveSource: index == kLiveIndex,
    );
    try {
      await _player.setAudioSource(_sourceFor(index), preload: true);
      _loadedIndex = index;
      _failures = 0;
      _pausedAt = null;
      _playedSinceLoad = false;
      _emit(
        status: _player.playing ? LiveStatus.playing : LiveStatus.buffering,
        reconnectAttempt: 0,
        clearError: true,
      );
      _startDriftTracking(index == kLiveIndex);
      return true;
    } catch (e) {
      _onFailure(e);
      return false;
    }
  }

  void _attachListeners() {
    // `setAudioSource` throws for failures we cause; errorStream carries the
    // ones that happen later, mid-playback, which are the ones users actually
    // hit. Nothing in the old code listened to it at all.
    _errorSub = _player.errorStream.listen(_onFailure);

    _stateSub = _player.playerStateStream.listen((state) {
      if (_disposed) return;
      switch (state.processingState) {
        case ProcessingState.loading:
          _emit(status: LiveStatus.connecting);
        case ProcessingState.buffering:
          _emit(status: LiveStatus.buffering);
        case ProcessingState.ready:
          if (state.playing) _reportTapToSound();
          _emit(status: state.playing ? LiveStatus.playing : LiveStatus.paused);
        case ProcessingState.completed:
          // A live stream that "completes" has actually been cut off by the
          // server. Treat it as a failure so it reconnects.
          if (_loadedIndex == kLiveIndex && _wantsPlayback) {
            _onFailure(Exception('stream ended'));
          }
        case ProcessingState.idle:
          break;
      }
    });
  }

  /// Sample the gap between the playhead and the newest buffered audio.
  ///
  /// Once a second is plenty for a readout measured in seconds, and it costs
  /// nothing next to subscribing to `positionStream`, which fires about
  /// sixty-two times a second on a live source.
  void _startDriftTracking(bool isLive) {
    _driftTimer?.cancel();
    if (!isLive) return;
    _driftTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      final raw = _player.bufferedPosition - _player.position;
      final gap = raw.isNegative ? Duration.zero : raw;
      // The readout is in whole seconds, so emitting sub-second changes would
      // rebuild the widget for nothing.
      if (gap.inSeconds == _live.value.behindLive.inSeconds) return;
      _emit(behindLive: gap);
    });
  }

  void _onFailure(Object error) {
    if (_disposed) return;

    // A failure with nobody listening must not start a retry loop.
    //
    // This is the expected end of every warm-up that goes unused. The player
    // fills `maxBufferDuration`, stops reading, Icecast decides we are a slow
    // client and hangs up, roughly a minute and a half after launch. Retrying
    // that would reconnect, refill, get dropped again, and burn battery and
    // data on a stream nobody asked for. Forgetting the source instead costs
    // the next tap a normal cold start, which is the honest price.
    if (!_wantsPlayback) {
      _failures = 0;
      _loadedIndex = -1;
      _driftTimer?.cancel();
      _emit(
        status: LiveStatus.idle,
        behindLive: Duration.zero,
        clearError: true,
        reconnectAttempt: 0,
      );
      return;
    }

    _failures++;

    // Alternate tiers once one has failed repeatedly. On web there is no
    // second tier, so this is a no-op there and it just keeps retrying.
    if (_failures % _failuresBeforeTierSwitch == 0) {
      final next = _quality.fallback;
      if (next != null) _quality = next;
    }

    final delay = _backoff[math.min(_failures - 1, _backoff.length - 1)];
    _emit(
      status: LiveStatus.failed,
      quality: _quality,
      error: error.toString(),
      reconnectAttempt: _failures,
    );

    // Guarded on kReleaseMode, not kDebugMode: profile builds are where this
    // gets exercised on a real device, and kDebugMode is false there.
    if (!kReleaseMode) {
      debugPrint('[audio] failure $_failures on ${_quality.name}, '
          'retrying in ${delay.inMilliseconds}ms: $error');
    }

    _cancelReconnect();
    _reconnectTimer = Timer(delay, () async {
      if (_disposed) return;
      final ok = await _load(_loadedIndex < 0 ? kLiveIndex : _loadedIndex);
      if (ok && _wantsPlayback) unawaited(_player.play());
    });
  }

  void _reportTapToSound() {
    final watch = _tapToSound;
    if (watch == null) return;
    _tapToSound = null;
    if (kReleaseMode) return;
    debugPrint('[audio] tap to sound: ${watch.elapsedMilliseconds}ms '
        '(source $_loadedIndex, ${_quality.name})');
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _emit({
    LiveStatus? status,
    StreamQuality? quality,
    Duration? behindLive,
    String? error,
    bool clearError = false,
    int? reconnectAttempt,
    bool? isLiveSource,
  }) {
    if (_disposed || _live.isClosed) return;
    final next = _live.value.copyWith(
      status: status,
      quality: quality ?? _quality,
      behindLive: behindLive,
      error: error,
      clearError: clearError,
      reconnectAttempt: reconnectAttempt,
      isLiveSource: isLiveSource,
    );
    _live.add(next);
  }

  // --------------------------------------------------------------- streams

  /// Position, buffer and duration for the progress bar.
  ///
  /// Built once and reused. `createPositionStream` allocates a new stream on
  /// every call, and the default `positionStream` asks for a 16 ms floor,
  /// which a live source collapses onto because its duration is null. That had
  /// the progress bar rebuilding about sixty-two times a second inside two
  /// nested `BackdropFilter`s, to draw a bar that live playback renders at zero
  /// width anyway. 200 ms is finer than anyone can see on a progress bar.
  Stream<AudioProgressState> get positionDataStream {
    return _progressStream ??= Rx.combineLatest3<Duration, Duration, Duration?,
        AudioProgressState>(
      _player.createPositionStream(
        steps: 800,
        minPeriod: const Duration(milliseconds: 200),
        maxPeriod: const Duration(milliseconds: 500),
      ),
      _player.bufferedPositionStream,
      _player.durationStream,
      (position, buffered, duration) => AudioProgressState(
        position: position,
        bufferedPosition: buffered,
        totalDuration: duration,
      ),
    ).distinct(
      (a, b) =>
          a.position == b.position &&
          a.bufferedPosition == b.bufferedPosition &&
          a.totalDuration == b.totalDuration,
    );
  }

  Stream<PlayerState> get playStateStream => _player.playerStateStream;

  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  void dispose() {
    _disposed = true;
    _cancelReconnect();
    _driftTimer?.cancel();
    _errorSub?.cancel();
    _stateSub?.cancel();
    _live.close();
    _player.dispose();
  }
}

/// The player lives as long as the app does.
///
/// This was `Provider.autoDispose` with no `ref.onDispose`, which is the worst
/// of both: Riverpod would drop the controller when the last widget stopped
/// watching, and nothing ever released the native player, so `dispose()` had
/// zero callers. Background audio also has to outlive any particular screen.
final audioController = Provider<AudioController>((ref) {
  final player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        // Start on one second of audio instead of the 2.5 s default. On the
        // 96 kbps tier that is 12 KB, which arrives roughly 370 ms sooner.
        bufferForPlaybackDuration: Duration(seconds: 1),
        // The one users feel most: how long silence lasts after a network
        // blip. Five seconds is a long time to stare at a playing button.
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        minBufferDuration: Duration(seconds: 10),
        // Caps how far a pause can drift before Icecast drops us for being a
        // slow reader. It also caps what an unused warm-up downloads, roughly
        // 360 KB at 96 kbps. Larger buys nothing while playing, because a live
        // stream sends at realtime once its opening burst is spent, so the
        // buffer never grows past that on its own.
        maxBufferDuration: Duration(seconds: 30),
        prioritizeTimeOverSizeThresholds: true,
      ),
      darwinLoadControl: DarwinLoadControl(
        // AVPlayer defaults to delaying playback until it is confident it will
        // not stall. For live radio, starting sooner is worth the risk.
        automaticallyWaitsToMinimizeStalling: false,
        preferredForwardBufferDuration: Duration(seconds: 15),
      ),
    ),
  );
  final controller = AudioController(player);

  // Reconnect the moment the radio comes back rather than waiting out a
  // backoff that was only ever a guess about why the connection died.
  ref.listen<AsyncValue<bool>>(connectivityController, (previous, next) {
    final wasOffline = previous?.value == false;
    if (wasOffline && next.value == true) {
      unawaited(controller.onNetworkRestored());
    }
  });

  ref.onDispose(controller.dispose);
  return controller;
});

/// Live stream status, tier and drift, for widgets that render the live UI.
final livePlaybackProvider = StreamProvider<LivePlaybackState>((ref) {
  final controller = ref.watch(audioController);
  return controller.liveStream;
});

final audioProgressProvider = StreamProvider<AudioProgressState>((ref) {
  return ref.watch(audioController).positionDataStream;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.watch(audioController).playStateStream;
});

final currentIndexProvider = StreamProvider<int?>((ref) {
  return ref.watch(audioController).currentIndexStream;
});

final sequenceStateProvider = StreamProvider<SequenceState?>((ref) {
  return ref.watch(audioController).sequenceStateStream;
});
