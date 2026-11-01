import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/media_session/live_darbar_audio_handler.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';

/// The parts of [AudioController] the handler reads, by hand.
///
/// The real one needs a platform player. Everything the handler decides sits
/// on this side of that line.
class _FakeController extends Fake implements AudioController {
  final events = StreamController<PlaybackEvent>.broadcast(sync: true);
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final lives = StreamController<LivePlaybackState>.broadcast(sync: true);
  final sources = StreamController<int>.broadcast(sync: true);

  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<PlayerState> get playStateStream => states.stream;
  @override
  Stream<LivePlaybackState> get liveStream => lives.stream;
  @override
  Stream<int> get sourceStream => sources.stream;

  @override
  PlayerState playerState = PlayerState(false, ProcessingState.idle);
  @override
  LivePlaybackState liveState = const LivePlaybackState();
  @override
  int sourceIndex = kLiveIndex;
  @override
  bool wantsPlayback = false;
  @override
  bool isStopped = false;
  @override
  bool canSeek = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration bufferedPosition = Duration.zero;
  @override
  Duration? duration;

  Map<int, Uri> art = {
    kLiveIndex: Uri.file('/files/artwork/0.jpg'),
    kMukhwakIndex: Uri.file('/files/artwork/1.jpg'),
    kKathaIndex: Uri.file('/files/artwork/2.jpg'),
  };
  @override
  Future<Map<int, Uri>> artworkUris() async => art;

  /// Every call the handler made, in order.
  final calls = <String>[];
  Object? seekError;

  // The real controller wants sound the moment play is called, before it
  // awaits anything, and a play that arrives while a load is running joins
  // that load and emits nothing. The player says nothing either until the load
  // is done. These two behave the same way, so a test sees what the handler
  // sees on a cold start.
  Completer<void>? _load;

  /// The launch warm-up is running: the player is loading the live stream.
  /// What the controller emitted when it began is already in these fields,
  /// and nothing more is emitted until [finishWarmUp].
  void startWarmUp() {
    _load = Completer<void>();
    playerState = PlayerState(false, ProcessingState.loading);
    liveState = const LivePlaybackState(status: LiveStatus.connecting);
  }

  void finishWarmUp() {
    final load = _load;
    if (load != null && !load.isCompleted) load.complete();
  }

  Future<void> _asked() async {
    wantsPlayback = true;
    isStopped = false;
    await _load?.future;
  }

  @override
  Future<void> play([int index = kLiveIndex]) {
    calls.add('play $index');
    return _asked();
  }

  @override
  Future<void> resume() {
    calls.add('resume');
    return _asked();
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    wantsPlayback = false;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    wantsPlayback = false;
    isStopped = true;
  }
  @override
  Future<void> seek(Duration duration) async {
    if (seekError != null) throw seekError!;
    calls.add('seek ${duration.inSeconds}');
  }

  /// A recording that is loaded, 20 minutes long, at [at].
  void loadRecording(int index, {Duration at = const Duration(minutes: 5)}) {
    sourceIndex = index;
    canSeek = true;
    duration = const Duration(minutes: 20);
    position = at;
  }

  /// The listener tapped play and sound is on.
  void startPlaying({ProcessingState processing = ProcessingState.ready}) {
    wantsPlayback = true;
    playerState = PlayerState(true, processing);
    states.add(playerState);
  }
}

void main() {
  late _FakeController controller;
  late LiveDarbarAudioHandler handler;
  var clock = DateTime(2026, 11, 2, 9);

  setUp(() async {
    clock = DateTime(2026, 11, 2, 9);
    controller = _FakeController();
    handler = LiveDarbarAudioHandler(controller, now: () => clock);
    await pumpEventQueue();
  });

  tearDown(() => handler.dispose());

  group('browse tree', () {
    test('the root lists live, Hukamnama and Katha, with art', () async {
      final items = await handler.getChildren(AudioService.browsableRootId);
      expect(items.map((item) => item.title), [
        'Live Kirtan',
        'Hukamnama',
        'Katha',
      ]);
      expect(items.every((item) => item.playable == true), isTrue);
      expect(
        items.every((item) => item.artist == 'Sri Harmandir Sahib, Amritsar'),
        isTrue,
      );
      expect(items.map((item) => item.artUri), [
        controller.art[kLiveIndex],
        controller.art[kMukhwakIndex],
        controller.art[kKathaIndex],
      ]);
    });

    test('recent offers what was asked for last', () async {
      controller.sourceIndex = kKathaIndex;
      final items = await handler.getChildren(AudioService.recentRootId);
      expect(items.map((item) => item.id), ['2']);
    });

    test('nothing nests below an item', () async {
      expect(await handler.getChildren('0'), isEmpty);
      expect(await handler.getChildren('anything'), isEmpty);
    });

    test('getMediaItem finds an item by id', () async {
      expect((await handler.getMediaItem('1'))?.title, 'Hukamnama');
      expect(await handler.getMediaItem('nope'), isNull);
    });

    test('search answers with the item a query picks', () async {
      final hits = await handler.search('katha');
      expect(hits.map((item) => item.id), ['2']);
      expect((await handler.search('kirtan')).map((item) => item.id), ['0']);
      expect((await handler.search('mukh wak')).map((item) => item.id), ['1']);
    });

    test('search finds nothing for a query with no keyword', () async {
      expect(await handler.search('weather'), isEmpty);
      expect(await handler.search('taylor swift'), isEmpty);
      expect(await handler.search(''), isEmpty);
    });

    test('search hands back the painting that Auto can read', () async {
      final hits = await handler.search('hukamnama');
      expect(hits.single.artUri, controller.art[kMukhwakIndex]);
    });
  });

  group('voice', () {
    test('playFromSearch plays the source the query names', () async {
      await handler.playFromSearch('play live kirtan');
      await handler.playFromSearch('hukamnama');
      await handler.playFromSearch('ਕਥਾ');
      expect(controller.calls, ['play 0', 'play 1', 'play 2']);
    });

    test('an empty or unknown query plays live', () async {
      await handler.playFromSearch('');
      await handler.playFromSearch('something else');
      expect(controller.calls, ['play 0', 'play 0']);
    });

    test('playFromMediaId plays the item with that id', () async {
      await handler.playFromMediaId('1');
      await handler.playFromMediaId('2');
      await handler.playFromMediaId('0');
      expect(controller.calls, ['play 1', 'play 2', 'play 0']);
    });

    test('a bare play resumes what the listener had', () async {
      await handler.play();
      expect(controller.calls, ['resume']);
    });

    test('a prepare names the source for the play that follows', () async {
      await handler.prepareFromSearch('katha');
      await handler.play();
      await handler.play();
      expect(controller.calls, ['play 2', 'resume']);
    });

    test('a prepare by media id works the same way', () async {
      await handler.prepareFromMediaId('1');
      await handler.play();
      expect(controller.calls, ['play 1']);
    });

    test('a prepare that nobody followed is forgotten', () async {
      await handler.prepareFromSearch('katha');
      clock = clock.add(const Duration(minutes: 5));
      await handler.play();
      expect(controller.calls, ['resume']);
    });

    test('a pause cancels a prepare', () async {
      await handler.prepareFromSearch('katha');
      await handler.pause();
      await handler.play();
      expect(controller.calls, ['pause', 'resume']);
    });
  });

  group('transport', () {
    test('pause and stop reach the controller', () async {
      await handler.pause();
      await handler.stop();
      expect(controller.calls, ['pause', 'stop']);
    });

    test('a headset click toggles between play and pause', () async {
      await handler.click();
      expect(controller.calls, ['resume']);

      controller.startPlaying();
      await handler.click();
      expect(controller.calls, ['resume', 'pause']);
    });
  });

  group('live has no timeline', () {
    setUp(() {
      controller
        ..sourceIndex = kLiveIndex
        ..canSeek = false;
    });

    test('seek does nothing', () async {
      await handler.seek(const Duration(minutes: 3));
      expect(controller.calls, isEmpty);
    });

    test('fast forward and rewind do nothing', () async {
      await handler.fastForward();
      await handler.rewind();
      expect(controller.calls, isEmpty);
    });

    test('skip next and previous do nothing', () async {
      await handler.skipToNext();
      await handler.skipToPrevious();
      await handler.click(MediaButton.next);
      await handler.click(MediaButton.previous);
      expect(controller.calls, isEmpty);
    });

    test('nothing throws', () async {
      controller.seekError = StateError('live cannot seek');
      await handler.seek(const Duration(minutes: 3));
      await handler.fastForward();
      await handler.rewind();
    });
  });

  group('recordings', () {
    setUp(() => controller.loadRecording(kKathaIndex));

    test('fast forward jumps 30 seconds', () async {
      await handler.fastForward();
      expect(controller.calls, ['seek ${5 * 60 + 30}']);
    });

    test('rewind jumps 15 seconds', () async {
      await handler.rewind();
      expect(controller.calls, ['seek ${5 * 60 - 15}']);
    });

    test('next and previous take the same jumps', () async {
      await handler.skipToNext();
      await handler.skipToPrevious();
      expect(controller.calls, ['seek ${5 * 60 + 30}', 'seek ${5 * 60 - 15}']);
    });

    test('a rewind near the start stops at zero', () async {
      controller.position = const Duration(seconds: 4);
      await handler.rewind();
      expect(controller.calls, ['seek 0']);
    });

    test('a fast forward near the end stops at the end', () async {
      controller.position = const Duration(minutes: 19, seconds: 50);
      await handler.fastForward();
      expect(controller.calls, ['seek ${20 * 60}']);
    });

    test('seek goes where it is told, within the recording', () async {
      await handler.seek(const Duration(minutes: 12));
      await handler.seek(const Duration(hours: 3));
      await handler.seek(const Duration(seconds: -5));
      expect(controller.calls, ['seek ${12 * 60}', 'seek ${20 * 60}', 'seek 0']);
    });

    test('a recording that is still loading cannot be seeked', () async {
      controller.canSeek = false;
      await handler.seek(const Duration(minutes: 12));
      await handler.fastForward();
      expect(controller.calls, isEmpty);
    });

    test('a failing seek does not throw into the platform', () async {
      controller.seekError = StateError('player is gone');
      await handler.seek(const Duration(minutes: 12));
      await handler.fastForward();
      expect(controller.calls, isEmpty);
    });
  });

  group('media session state', () {
    test('stays idle while the app only warms the stream up', () async {
      controller.playerState = PlayerState(false, ProcessingState.ready);
      controller.states.add(controller.playerState);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.idle);
      expect(handler.playbackState.value.controls, isEmpty);
    });

    test('publishes the current item, with its painting', () async {
      expect(handler.mediaItem.value?.id, '0');
      expect(handler.mediaItem.value?.title, 'Live Kirtan');
      expect(handler.mediaItem.value?.artUri, controller.art[kLiveIndex]);
      expect(handler.mediaItem.value?.isLive, isTrue);
    });

    test('live playing offers pause and stop and no jumps', () async {
      controller.startPlaying();
      final state = handler.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.controls, [MediaControl.pause, MediaControl.stop]);
    });

    test('a different source changes the item and the buttons', () async {
      controller.loadRecording(kMukhwakIndex);
      controller.startPlaying();
      controller.sources.add(kMukhwakIndex);

      expect(handler.mediaItem.value?.title, 'Hukamnama');
      expect(handler.mediaItem.value?.duration, const Duration(minutes: 20));
      final state = handler.playbackState.value;
      expect(
        state.controls.map((control) => control.action),
        [
          MediaAction.rewind,
          MediaAction.pause,
          MediaAction.fastForward,
          MediaAction.stop,
        ],
      );
      expect(state.systemActions, contains(MediaAction.seek));
    });

    test('a stop takes the session back to idle', () async {
      controller.startPlaying();
      expect(handler.playbackState.value.playing, isTrue);

      await handler.stop();
      controller.playerState = PlayerState(false, ProcessingState.idle);
      controller.states.add(controller.playerState);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.idle);
      expect(handler.playbackState.value.playing, isFalse);
    });

    test('a play after a stop brings the session back', () async {
      controller.startPlaying();
      await handler.stop();
      controller.playerState = PlayerState(false, ProcessingState.idle);
      controller.states.add(controller.playerState);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.idle);

      await handler.play();
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.loading);
    });

    test('a server that drops a paused stream does not end the session',
        () async {
      controller.startPlaying();
      // A phone call pauses the player, and the listener did not stop it.
      controller.wantsPlayback = false;
      controller.playerState = PlayerState(false, ProcessingState.ready);
      controller.states.add(controller.playerState);

      // 45 to 90 seconds later the server hangs up. The player goes idle,
      // and the controller forgets the connection and reports idle.
      controller.playerState = PlayerState(false, ProcessingState.idle);
      controller.liveState = const LivePlaybackState(status: LiveStatus.idle);
      controller.states.add(controller.playerState);
      controller.lives.add(controller.liveState);

      // An idle state here makes audio_service stop the foreground service,
      // and the play after the call could not start another one.
      final state = handler.playbackState.value;
      expect(state.processingState, isNot(AudioProcessingState.idle));
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.playing, isFalse);
      expect(state.controls.first, MediaControl.play);
    });

    test('the play that follows a drop reconnects', () async {
      controller.startPlaying();
      controller.wantsPlayback = false;
      controller.playerState = PlayerState(false, ProcessingState.idle);
      controller.liveState = const LivePlaybackState(status: LiveStatus.idle);
      controller.states.add(controller.playerState);

      await handler.play();

      expect(controller.calls, ['resume']);
      final state = handler.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.processingState, AudioProcessingState.loading);
    });

    test('the service stays in the foreground through a pause', () {
      const config = LiveDarbarAudioHandler.serviceConfig;
      // The default drops the service to the background on a pause, and the
      // resume after a call then needs startForegroundService from the
      // background, which Android 12 and later refuse.
      expect(config.androidStopForegroundOnPause, isFalse);
      expect(config.androidNotificationOngoing, isFalse);
    });

    test('a pause keeps the session, with a play button', () async {
      controller.startPlaying();
      controller.wantsPlayback = false;
      controller.playerState = PlayerState(false, ProcessingState.ready);
      controller.states.add(controller.playerState);

      final state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.playing, isFalse);
      expect(state.controls.first, MediaControl.play);
    });

    test('a tap shows connecting before the player moves', () async {
      controller.wantsPlayback = true;
      controller.liveState =
          const LivePlaybackState(status: LiveStatus.connecting);
      controller.lives.add(controller.liveState);

      final state = handler.playbackState.value;
      expect(state.processingState, AudioProcessingState.loading);
      expect(state.playing, isTrue);
    });
  });

  // A cold start from a Bluetooth button or Android Auto. The warm-up load
  // that main.dart starts is still running when the command arrives, so the
  // controller's play joins it and emits nothing until the player moves.
  // audio_service calls startForeground when it first hears "playing", and
  // Android gives it 5 to 10 seconds after startForegroundService.
  group('a play while the launch load is still running', () {
    setUp(() => controller.startWarmUp());
    tearDown(() => controller.finishWarmUp());

    test('the fake emits nothing, as the real controller does', () async {
      var heard = 0;
      final subscriptions = [
        controller.events.stream.listen((_) => heard++),
        controller.states.stream.listen((_) => heard++),
        controller.lives.stream.listen((_) => heard++),
        controller.sources.stream.listen((_) => heard++),
      ];
      final pending = controller.resume();
      await pumpEventQueue();
      expect(heard, 0);
      controller.finishWarmUp();
      await pending;
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    });

    test('a bare play publishes connecting before the load is done', () async {
      expect(handler.playbackState.value.playing, isFalse);

      final pending = handler.play();
      final state = handler.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.processingState, AudioProcessingState.loading);
      expect(state.controls, [MediaControl.pause, MediaControl.stop]);

      controller.finishWarmUp();
      await pending;
    });

    test('a play from a voice search does too', () async {
      final pending = handler.playFromSearch('live kirtan');
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.loading);

      controller.finishWarmUp();
      await pending;
    });

    test('so does a play of an item in the car', () async {
      final pending = handler.playFromMediaId('0');
      expect(handler.playbackState.value.playing, isTrue);
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.loading);

      controller.finishWarmUp();
      await pending;
    });

    test('so does the play that follows a prepare', () async {
      await handler.prepareFromSearch('live');
      final pending = handler.play();
      expect(handler.playbackState.value.playing, isTrue);
      expect(controller.calls, ['play 0']);

      controller.finishWarmUp();
      await pending;
    });
  });
}
