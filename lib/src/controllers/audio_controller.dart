import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/controllers/daily_content_controller.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/daily_edition.dart';
import 'package:live_darbar/src/controllers/quality_mode_controller.dart';
import 'package:live_darbar/src/core/artwork_store.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/network_snapshot.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:live_darbar/src/models/resume_point.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:rxdart/rxdart.dart';

/// Index of the live kirtan stream in the source list.
const kLiveIndex = 0;
const kMukhwakIndex = 1;
const kKathaIndex = 2;

/// What a car or Bluetooth display shows beside the title.
///
/// Those screens read artist and album from the media session and show a blank
/// where there is none, so the title was the only thing on them.
const _kArtist = 'Sri Harmandir Sahib, Amritsar';
const _kAlbum = 'Live Darbar';

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
  /// [policy] decides which live tier to open and when to change it.
  ///
  /// [savedMode] is the listener's stored quality setting, which arrives a few
  /// milliseconds after launch. The first connection waits for it, so someone
  /// on Data Saver never opens the high tier first.
  AudioController(
    this._player,
    this._daily, {
    QualityPolicy? policy,
    Future<QualityMode>? savedMode,
    ArtworkStore? artwork,
  })  : _policy = policy ?? QualityPolicy(),
        _artwork = artwork ?? ArtworkStore() {
    _quality = _policy.preferred;
    _live.add(LivePlaybackState(quality: _quality));
    _settingsReady = savedMode == null
        ? Future<void>.value()
        : savedMode.then(_applySavedMode, onError: (Object _) {});
    _attachListeners();
    unawaited(_warmUp());
  }

  final AudioPlayer _player;

  final QualityPolicy _policy;

  /// Completes once the saved quality mode is in [_policy].
  late final Future<void> _settingsReady;

  final ArtworkStore _artwork;

  /// Local artwork per source index, filled in by the first load.
  Map<int, Uri> _artUris = const {};

  /// Settles which day's Mukhwak or Katha is actually available before the
  /// player is handed a URL. See [DailyContentResolver] for why that has to
  /// happen first rather than as error recovery.
  final DailyContentResolver _daily;

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

  /// How long a load may take before it counts as a failure.
  ///
  /// `setAudioSource` has no deadline of its own. On a link that accepts the
  /// connection and then sends nothing, which is what a weak signal or a
  /// captive portal does, the future never completes and the listener watches
  /// a spinner for as long as the platform keeps the socket open. Ten seconds
  /// is several times a normal connect, and short enough that the backoff and
  /// the tier fallback get their turn.
  static const _connectTimeout = Duration(seconds: 10);

  late StreamQuality _quality;

  /// Where Mukhwak or Katha was, so a reload does not start them over.
  final _resume = ResumePoint();

  final _live = BehaviorSubject<LivePlaybackState>.seeded(
    const LivePlaybackState(),
  );

  /// Index currently handed to the player, or -1 when nothing is loaded.
  int _loadedIndex = -1;

  /// What the listener last asked for, kept across reconnects so that a
  /// recovery resumes playback rather than leaving them staring at a play
  /// button they already pressed.
  ///
  /// It follows the player, not just this class. A pause from a headset
  /// button, the notification, a headphone unplug or a phone call never passes
  /// through [pause], so [_onPlayingChanged] copies the player's own playing
  /// flag in here. Without that, a reconnect minutes later would start sound
  /// the listener had stopped.
  bool _wantsPlayback = false;

  /// False between loading a source and the first play on it.
  ///
  /// Distinguishes "resuming my own pause" from "pressing play for the first
  /// time on a connection that has been quietly buffering since launch", which
  /// want opposite things. See [_shouldReopenLive].
  bool _playedSinceLoad = false;

  DateTime? _pausedAt;

  /// The tier a retry of the preferred tier left, while that retry is still
  /// connecting. Null otherwise. See [_onFailure].
  StreamQuality? _retryingFrom;

  /// The open live connection belongs to a network that is gone. Set by a
  /// handoff while nobody is listening, read by [_shouldReopenLive].
  bool _connectionStale = false;

  /// Times the only number that matters: tap to sound.
  ///
  /// Started when playback is requested and read once the player reports it is
  /// actually playing. Logged outside release builds so the latency work can
  /// be checked on a real device instead of argued about.
  Stopwatch? _tapToSound;

  /// The source the listener last asked for, whether or not it loaded.
  ///
  /// Distinct from [_loadedIndex], which only moves on success. See
  /// [_retryIndex].
  int _requestedIndex = -1;

  /// A load already running, so a second caller joins instead of restarting.
  Future<bool>? _inFlightLoad;
  int _inFlightIndex = -1;

  int _failures = 0;
  Timer? _reconnectTimer;
  Timer? _tickTimer;
  StreamSubscription<PlayerException>? _errorSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<bool>? _playingSub;
  PlayerState? _lastState;
  Stream<AudioProgressState>? _progressStream;
  bool _disposed = false;

  // ---------------------------------------------------------------- sources

  /// The media session entry for source [index].
  ///
  /// The id stays the index as a string, because the views read it back from
  /// the sequence state to know which source is current.
  ///
  /// Artwork is a `file:` URI to a local copy of the painting, or null when
  /// there is none (web, or the copy failed). See [ArtworkStore].
  MediaItem _tag(int index, String title) => MediaItem(
        id: '$index',
        title: title,
        artist: _kArtist,
        album: _kAlbum,
        artUri: _artUris[index],
      );

  /// The daily recording behind [index], or null for the live stream.
  DailyAsset? _assetFor(int index) => switch (index) {
        kMukhwakIndex => DailyAsset.hukamnama,
        kKathaIndex => DailyAsset.katha,
        _ => null,
      };

  /// [edition] is the resolved day for a daily source, and is null only for
  /// the live stream. The undated URL stands in if one ever arrives null
  /// anyway, because playing the newest recording SGPC has is a better answer
  /// than throwing at somebody who pressed play.
  AudioSource _sourceFor(int index, DailyEdition? edition) {
    switch (index) {
      case kLiveIndex:
        return AudioSource.uri(
          Uri.parse(_quality.url),
          tag: _tag(kLiveIndex, 'Live Kirtan'),
        );
      case kMukhwakIndex:
        return AudioSource.uri(
          Uri.parse(edition?.url ?? DailyAsset.hukamnama.latestUrl),
          tag: _tag(kMukhwakIndex, 'Mukhwak'),
        );
      case kKathaIndex:
        return AudioSource.uri(
          Uri.parse(edition?.url ?? DailyAsset.katha.latestUrl),
          tag: _tag(kKathaIndex, 'Mukhwak Katha'),
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

    // Choosing a different source starts it from the beginning. Asking for the
    // same one again, after a drop for example, picks up where it left off.
    if (_requestedIndex != index) _resume.clear();

    // The loaded source and the requested one can differ without a failure: a
    // tap on Mukhwak replaces the playlist at once, but if that load then
    // times out while the platform keeps connecting, `_loadedIndex` still says
    // live. Trusting it alone would call the next tap on Live a no-op, and
    // Mukhwak would start when its connection finally came up.
    final switching = _requestedIndex != index || _loadedIndex != index;
    final needsLoad = switching || _isDead;
    if (needsLoad) {
      // Switching away from a failed attempt is a fresh start, so go back to
      // the preferred tier rather than staying stuck on a fallback forever.
      if (switching) {
        _quality = _policy.preferred;
        _failures = 0;
      }
      final ok = await _load(index);
      if (!ok) return;
    } else if (index == kLiveIndex && _shouldReopenLive) {
      final ok = await _load(index);
      if (!ok) return;
    }

    // A load takes a second or more, and the listener can pause in that time
    // with a headset button or a call. Starting sound now would undo it.
    if (!_wantsPlayback) return;

    _pausedAt = null;
    _playedSinceLoad = true;
    unawaited(_player.play());
  }

  /// Resume whatever the listener last had, without changing source.
  Future<void> resume() => play(_retryIndex);

  Future<void> pause() async {
    _wantsPlayback = false;
    _pausedAt = DateTime.now();
    // A reconnect still waiting on its backoff would fire after the pause. It
    // would reload the stream and show connecting over a paused player, for
    // nobody. An outside pause already cancels it, in _onPlayingChanged.
    _cancelReconnect();
    _rememberPosition();
    await _player.pause();
    _emit(status: LiveStatus.paused);
  }

  Future<void> stop() async {
    _wantsPlayback = false;
    _cancelReconnect();
    _resume.clear();
    await _player.stop();
    await _player.seek(Duration.zero);
    _emit(
      status: LiveStatus.idle,
      behindLive: Duration.zero,
      clearEdition: true,
    );
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
    if (ok && _wantsPlayback) unawaited(_player.play());
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
    // Whatever failed before says nothing about the network that is here now.
    _policy.networkChanged();
    _retryingFrom = null;
    if (_wantsPlayback) {
      _cancelReconnect();
      _failures = 0;
      _quality = _policy.preferred;
      final ok = await _load(_retryIndex, force: true);
      if (ok && _wantsPlayback) unawaited(_player.play());
    } else if (_loadedIndex < 0) {
      unawaited(_warmUp());
    }
  }

  /// Act on one network replacing another, Wi-Fi to mobile data or back.
  ///
  /// There is no gap for [onNetworkRestored] to notice. The stream socket is
  /// bound to the interface that went away, so it is dead, but the player does
  /// not find out until a read times out, which is many seconds of silence.
  /// Reloading straight away skips most of that.
  ///
  /// Live only. A recording that loses its socket fails through the error
  /// path and reopens at the saved position.
  Future<void> onNetworkHandoff() async {
    if (_disposed) return;
    _policy.networkChanged();
    _retryingFrom = null;
    if (_retryIndex != kLiveIndex) return;
    if (_wantsPlayback) {
      _cancelReconnect();
      _failures = 0;
      _quality = _policy.preferred;
      final ok = await _load(kLiveIndex, force: true);
      if (ok && _wantsPlayback) unawaited(_player.play());
    } else if (_loadedIndex == kLiveIndex) {
      // Paused, or warm and unused. Do not spend data on a stream nobody is
      // hearing. Mark it dead instead, so the next play reopens it rather than
      // resuming into a connection that no longer exists.
      _connectionStale = true;
    }
  }

  /// Apply the listener's quality setting to the stream that is playing.
  ///
  /// Called by the provider on every change of `qualityModeProvider`, so a UI
  /// only has to set the provider. A change that moves the preferred tier
  /// reloads live straight away: Data Saver should not keep spending data on
  /// the high tier until the next reconnect. A change that keeps it, such as
  /// Automatic to High, reloads nothing.
  Future<void> setQualityMode(QualityMode mode) async {
    if (_disposed || mode == _policy.mode) return;
    _policy.mode = mode;
    final target = _policy.preferred;
    if (target != _quality) await _switchTier(target);
  }

  /// The stored setting, once read. Nothing has connected yet, or it waited
  /// for this, so a change of tier here costs nothing.
  void _applySavedMode(QualityMode mode) {
    if (_disposed || mode == _policy.mode) return;
    _policy.mode = mode;
    if (_loadedIndex < 0) {
      _quality = _policy.preferred;
      _emit(quality: _quality);
    }
  }

  /// Move the live stream to [next], reloading it if it is the thing playing.
  ///
  /// Used for a setting change, a stall-driven drop and a retry of the
  /// preferred tier. Forced, because a plain load would join one already in
  /// flight, and that one is on the old URL.
  ///
  /// [retryingFrom] is set only when the move is a retry of the preferred tier,
  /// and names the tier to go back to if the retry cannot connect.
  Future<void> _switchTier(
    StreamQuality next, {
    StreamQuality? retryingFrom,
  }) async {
    _retryingFrom = retryingFrom;
    _quality = next;
    _failures = 0;
    _emit(quality: next);
    // Recordings have no tiers: the next live load picks [next] up by itself.
    if (_loadedIndex != kLiveIndex || _requestedIndex != kLiveIndex) return;
    _cancelReconnect();
    final ok = await _load(kLiveIndex, force: true);
    if (ok && _wantsPlayback) unawaited(_player.play());
  }

  // ------------------------------------------------------------- internals

  bool get _isDead {
    final s = _player.processingState;
    return s == ProcessingState.idle || s == ProcessingState.completed;
  }

  /// Which source a retry should reopen.
  ///
  /// [_loadedIndex] is only set once a load succeeds, so it is still -1 while
  /// the very first attempt at a source is failing. Falling back to
  /// [kLiveIndex] there meant that tapping Mukhwak on a bad connection quietly
  /// started live kirtan instead: the listener asked for one thing, the retry
  /// gave them another, and nothing said so. [_requestedIndex] records what
  /// was actually asked for, which is the thing worth retrying.
  int get _retryIndex {
    if (_requestedIndex >= 0) return _requestedIndex;
    return _loadedIndex < 0 ? kLiveIndex : _loadedIndex;
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
    if (_connectionStale) return true;
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
    _requestedIndex = index;
    // A retry only means something for the live stream it was started on.
    if (index != kLiveIndex) _retryingFrom = null;
    _emit(
      status: LiveStatus.connecting,
      clearError: true,
      behindLive: Duration.zero,
      isLiveSource: index == kLiveIndex,
      clearEdition: true,
    );
    try {
      // After every await below, a newer request for another source means this
      // load is stale and must stop. Resolving a cold Mukhwak can take 6
      // seconds, and a tap on Live in that time starts and finishes its own
      // load. Carrying on would then replace live with Mukhwak.

      // The saved quality setting is read from disk, so it can land a few
      // milliseconds after launch. Opening the stream before it does would
      // spend a warm-up buffer on the wrong tier. Already complete after the
      // first load, so this costs a microtask.
      if (index == kLiveIndex) {
        await _settingsReady.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () {},
        );
        if (_disposed || _requestedIndex != index) return false;
      }

      // The first run copies three paintings to disk, which takes a few
      // milliseconds. Later runs find them there. Bounded, because a slow disk
      // should cost the notification its picture and never the listener their
      // sound, and the same copy is picked up by whichever load comes next.
      _artUris = await _artwork.prepare().timeout(
            const Duration(seconds: 3),
            onTimeout: () => _artUris,
          );
      if (_disposed || _requestedIndex != index) return false;

      // Resolved before the player is touched, not after it fails. A dated
      // file that is not up yet answers 404, which the retry loop below would
      // treat as a transient fault and hammer on a backoff, and it is not one:
      // no amount of asking makes tomorrow's upload arrive early. The resolver
      // caches per day, so this costs one HEAD on the first Mukhwak or Katha
      // of the day and nothing after that. The live stream skips it entirely,
      // because it is the latency-critical path and it has no day.
      final asset = _assetFor(index);
      final edition = asset == null ? null : await _daily.resolve(asset);
      if (_disposed || _requestedIndex != index) return false;

      final isLive = index == kLiveIndex;
      // A deliberate reload of a healthy recording should land where the
      // playhead is now, not where the last once-a-second sample saw it. After
      // a failure the player has nothing better than that sample to offer.
      if (!isLive && _loadedIndex == index) _rememberPosition();
      final startAt = isLive ? null : _resume.startFor(index, DateTime.now());
      final tier = _quality;

      // The live stream has no position, so it always opens at the live edge.
      // A recording reopens where it stopped: without this, every drop sent
      // Mukhwak and Katha back to 0:00.
      await _player
          .setAudioSource(
            _sourceFor(index, edition),
            preload: true,
            initialPosition: startAt,
          )
          .timeout(_connectTimeout);
      // The request moved on while the platform connected. The newer load will
      // replace this source, so do not record it as the loaded one.
      if (_disposed || _requestedIndex != index) return false;
      _loadedIndex = index;
      _retryingFrom = null;
      _failures = 0;
      _pausedAt = null;
      _playedSinceLoad = false;
      _connectionStale = false;
      _emit(
        status: _player.playing ? LiveStatus.playing : LiveStatus.buffering,
        reconnectAttempt: 0,
        clearError: true,
        edition: edition,
      );
      _startTicker(index);
      // The tier moved while this connected, for example the listener picked
      // Data Saver during the load. What is playing no longer matches what was
      // asked for, so go again on the right one.
      if (isLive && tier != _quality) unawaited(_switchTier(_quality));
      return true;
    } on PlayerInterruptedException {
      // A newer load replaced this one, for example a tap on Mukhwak while the
      // warm-up was still connecting. That is not a failure: the newer load
      // owns the result, and reporting this one would schedule a retry of a
      // source nobody wants any more.
      return false;
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

    _playingSub = _player.playingStream.listen(_onPlayingChanged);

    _stateSub = _player.playerStateStream.listen((state) {
      if (_disposed) return;
      final previous = _lastState;
      _lastState = state;

      // Only clean playback counts towards trying the high tier again. A
      // pause, a stall and a reload each restart that clock.
      if (state.processingState == ProcessingState.ready && state.playing) {
        _policy.playbackHealthy(DateTime.now());
      } else {
        _policy.playbackInterrupted();
      }

      switch (state.processingState) {
        case ProcessingState.loading:
          _emit(status: LiveStatus.connecting);
        case ProcessingState.buffering:
          _emit(status: LiveStatus.buffering);
          if (_isStall(previous, state)) _onStall();
        case ProcessingState.ready:
          if (state.playing) _reportTapToSound();
          _emit(status: state.playing ? LiveStatus.playing : LiveStatus.paused);
        case ProcessingState.completed:
          // A live stream that "completes" has actually been cut off by the
          // server. Treat it as a failure so it reconnects.
          if (_loadedIndex == kLiveIndex && _wantsPlayback) {
            _onFailure(Exception('stream ended'));
          } else if (_loadedIndex != kLiveIndex) {
            // A recording that played to its end is finished, not interrupted.
            // The player keeps its playing flag, so without this a later
            // network change would reload the file and start it over unasked,
            // and the next play would resume from the final second. Pausing
            // the player makes its own flag agree with the intent.
            _wantsPlayback = false;
            _resume.clear();
            unawaited(_player.pause());
          }
        case ProcessingState.idle:
          break;
      }
    });
  }

  /// Whether the move from [previous] to [now] is audio running dry.
  ///
  /// A stall is playing, ready and then buffering again, on the live stream.
  /// Buffering that follows a load, a seek or a pause is the player getting
  /// started, and says nothing about the link, so it must not count.
  bool _isStall(PlayerState? previous, PlayerState now) =>
      _loadedIndex == kLiveIndex &&
      previous != null &&
      previous.processingState == ProcessingState.ready &&
      previous.playing &&
      now.playing;

  /// The live stream stalled once. The policy decides whether it was the
  /// third in a minute, which is the point to give up on the high tier.
  void _onStall() {
    final next = _policy.recordStall(DateTime.now(), _quality);
    if (!kReleaseMode) {
      debugPrint('[audio] stall on ${_quality.name}'
          '${next == null ? '' : ', dropping to ${next.name}'}');
    }
    if (next != null) unawaited(_switchTier(next));
  }

  /// Keep [_wantsPlayback] in step with the player.
  ///
  /// Every change this class makes to the player's playing flag follows a
  /// change to [_wantsPlayback], so a flag that already agrees is our own
  /// doing and needs nothing. A flag that disagrees came from outside, and the
  /// listener meant it.
  ///
  /// Outside pauses are the headset or notification button, a headphone
  /// unplug, a phone call, and another app taking audio focus. `just_audio`
  /// pauses itself for the last three and resumes itself after a call on iOS.
  /// That resume arrives here as an outside play, and runs the same path as a
  /// tap, so a call that outlasted the stream reconnects at the live edge
  /// instead of resuming into a dead connection.
  void _onPlayingChanged(bool playing) {
    if (_disposed || playing == _wantsPlayback) return;
    if (playing) {
      unawaited(play(_retryIndex));
      return;
    }
    _wantsPlayback = false;
    _pausedAt = DateTime.now();
    _rememberPosition();
    // A pending reconnect would start sound the listener has just stopped.
    _cancelReconnect();
    _emit(status: LiveStatus.paused);
  }

  /// Run the once-a-second housekeeping for the source at [index].
  ///
  /// Once a second is plenty for everything done here, and it costs nothing
  /// next to subscribing to `positionStream`, which fires about sixty-two
  /// times a second on a live source.
  void _startTicker(int index) {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      if (index == kLiveIndex) {
        _trackDrift();
        _maybeRetryPreferredTier();
      } else if (_player.playing) {
        _rememberPosition();
      }
    });
  }

  /// Sample the gap between the playhead and the newest buffered audio.
  void _trackDrift() {
    final raw = _player.bufferedPosition - _player.position;
    final gap = raw.isNegative ? Duration.zero : raw;
    // The readout is in whole seconds, so emitting sub-second changes would
    // rebuild the widget for nothing.
    if (gap.inSeconds == _live.value.behindLive.inSeconds) return;
    _emit(behindLive: gap);
  }

  /// Go back to the preferred tier once the link has earned it.
  ///
  /// Dropping to the low tier is only ever a response to a bad stretch, so
  /// without this the listener would stay on a third of the bitrate for the
  /// rest of the session after one tunnel. Only while sound is actually
  /// playing: reloading a stream nobody is hearing would spend data to
  /// improve nothing, and a pause restarts the policy's clock anyway.
  void _maybeRetryPreferredTier() {
    if (!_wantsPlayback || !_player.playing) return;
    if (_player.processingState != ProcessingState.ready) return;
    if (_loadedIndex != kLiveIndex || _requestedIndex != kLiveIndex) return;
    final now = DateTime.now();
    final target = _policy.retryTarget(now, _quality);
    if (target == null) return;
    if (!kReleaseMode) debugPrint('[audio] trying ${target.name} again');
    _policy.recordRetry(now);
    unawaited(_switchTier(target, retryingFrom: _quality));
  }

  /// Note where the loaded recording is, for the next reload.
  ///
  /// Sampled while playing rather than on demand because a failure is the case
  /// that matters, and by then the player has often already reset itself.
  void _rememberPosition() {
    if (_loadedIndex < 0 || _loadedIndex == kLiveIndex) return;
    final state = _player.processingState;
    if (state != ProcessingState.ready && state != ProcessingState.buffering) {
      return;
    }
    _resume.remember(_loadedIndex, _player.position, DateTime.now());
  }

  void _onFailure(Object error) {
    if (_disposed) return;

    // A retry of the preferred tier that cannot connect means that tier is out
    // of reach on this network, typically port 7339 blocked. Go straight back
    // to the tier that was working rather than failing twice first, and stop
    // trying. Each retry otherwise tears down a working stream for about 20
    // seconds, every 10 to 40 minutes, for as long as the app is open.
    final retriedFrom = _retryingFrom;
    if (retriedFrom != null) {
      _retryingFrom = null;
      _policy.recordRetryFailed();
      _quality = retriedFrom;
    }

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
      _tickTimer?.cancel();
      _emit(
        status: LiveStatus.idle,
        behindLive: Duration.zero,
        clearError: true,
        reconnectAttempt: 0,
        clearEdition: true,
      );
      return;
    }

    _failures++;

    // Alternate tiers once one has failed repeatedly. On web there is no
    // second tier, so this is a no-op there and it just keeps retrying.
    if (_failures % _failuresBeforeTierSwitch == 0) {
      final next = _quality.fallback;
      if (next != null) {
        _quality = next;
        // Landing off the preferred tier is a fallback to be undone later,
        // not a new home. Landing back on it needs no follow-up.
        if (next != _policy.preferred) _policy.noteFellBack(DateTime.now());
      }
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
    final target = _retryIndex;
    _reconnectTimer = Timer(delay, () async {
      if (_disposed) return;
      final ok = await _load(target);
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
    DailyEdition? edition,
    bool clearEdition = false,
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
      edition: edition,
      clearEdition: clearEdition,
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
        // The controller knows which source it loaded, so liveness is a fact
        // here rather than something the UI has to deduce from a duration the
        // two platforms describe differently.
        isLive: _loadedIndex == kLiveIndex,
      ),
    ).distinct(
      (a, b) =>
          a.position == b.position &&
          a.bufferedPosition == b.bufferedPosition &&
          a.totalDuration == b.totalDuration &&
          a.isLive == b.isLive,
    );
  }

  Stream<PlayerState> get playStateStream => _player.playerStateStream;

  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  void dispose() {
    _disposed = true;
    _cancelReconnect();
    _tickTimer?.cancel();
    _errorSub?.cancel();
    _stateSub?.cancel();
    _playingSub?.cancel();
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
  final quality = ref.read(qualityModeProvider.notifier);
  final controller = AudioController(
    player,
    ref.read(dailyContentResolver),
    policy: QualityPolicy(mode: ref.read(qualityModeProvider)),
    // The saved setting lands a moment after launch. The controller holds its
    // first connection back for it.
    savedMode: quality.ready.then((_) => ref.read(qualityModeProvider)),
  );

  // A change from a settings screen applies to the stream that is playing.
  ref.listen<QualityMode>(qualityModeProvider, (previous, next) {
    unawaited(controller.setQualityMode(next));
  });

  // Reconnect the moment the radio comes back rather than waiting out a
  // backoff that was only ever a guess about why the connection died. A move
  // from Wi-Fi to mobile data has no offline moment to wait for, and kills the
  // stream socket just the same, so it gets its own reload.
  ref.listen<AsyncValue<NetworkSnapshot>>(networkSnapshotProvider,
      (previous, next) {
    final snapshot = next.value;
    if (snapshot == null) return;
    switch (classifyTransition(previous?.value, snapshot)) {
      case NetworkTransition.restored:
        unawaited(controller.onNetworkRestored());
      case NetworkTransition.handoff:
        unawaited(controller.onNetworkHandoff());
      case NetworkTransition.lost || NetworkTransition.none:
        break;
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
