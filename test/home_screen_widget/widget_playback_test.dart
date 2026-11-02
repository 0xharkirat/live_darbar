import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/home_screen_widget/widget_playback.dart';
import 'package:live_darbar/src/home_screen_widget/widget_publisher.dart';
import 'package:live_darbar/src/media_session/media_catalog.dart';
import 'package:live_darbar/src/models/source_index.dart';
import 'package:rxdart/rxdart.dart';

const idle = WidgetPlayback.idle;
const playingLive = WidgetPlayback(WidgetPlayState.playing, WidgetSource.live);
const playingHukamnama =
    WidgetPlayback(WidgetPlayState.playing, WidgetSource.hukamnama);

PlaybackState session(AudioProcessingState processing, {bool playing = false}) =>
    PlaybackState(processingState: processing, playing: playing);

MediaItem item(int index) => MediaCatalog.item(index);

class _Recorder implements WidgetPublisher {
  final writes = <Map<String, String>>[];
  final _gate = <Completer<void>>[];
  bool hold = false;
  bool failNext = false;

  /// The decoded playback of each write, in order.
  List<Map<String, Object?>> get playbacks => [
        for (final write in writes)
          jsonDecode(write[WidgetKeys.playback]!) as Map<String, Object?>,
      ];

  @override
  Future<void> publish(Map<String, String> data) async {
    if (failNext) {
      failNext = false;
      throw StateError('launcher not ready');
    }
    if (hold) {
      final gate = Completer<void>();
      _gate.add(gate);
      await gate.future;
    }
    writes.add(data);
  }

  void release() {
    for (final gate in _gate) {
      gate.complete();
    }
    _gate.clear();
  }
}

void main() {
  group('every playback state maps to a widget state', () {
    // The whole table of the session states the handler can publish, and what
    // the widget must show for each. `playing` is the session's own flag: it
    // is true from the tap, through a connection that is still opening.
    final table = <(AudioProcessingState, bool), WidgetPlayState>{
      (AudioProcessingState.idle, false): WidgetPlayState.idle,
      (AudioProcessingState.idle, true): WidgetPlayState.idle,
      (AudioProcessingState.loading, true): WidgetPlayState.loading,
      (AudioProcessingState.loading, false): WidgetPlayState.paused,
      (AudioProcessingState.buffering, true): WidgetPlayState.loading,
      (AudioProcessingState.buffering, false): WidgetPlayState.paused,
      (AudioProcessingState.ready, true): WidgetPlayState.playing,
      (AudioProcessingState.ready, false): WidgetPlayState.paused,
      (AudioProcessingState.completed, true): WidgetPlayState.idle,
      (AudioProcessingState.completed, false): WidgetPlayState.idle,
      (AudioProcessingState.error, true): WidgetPlayState.idle,
      (AudioProcessingState.error, false): WidgetPlayState.idle,
    };

    test('the table covers every processing state, with and without sound', () {
      expect(table.length, AudioProcessingState.values.length * 2);
    });

    for (final MapEntry(key: (processing, playing), value: expected)
        in table.entries) {
      for (final index in kSourceIndexes) {
        test('${processing.name}, playing $playing, source $index', () {
          final result = widgetPlaybackFor(
            session(processing, playing: playing),
            item(index),
          );
          expect(result.state, expected);
          if (expected == WidgetPlayState.idle) {
            expect(result.source, isNull, reason: 'idle names no source');
          } else {
            expect(result.source, WidgetSource.values[index]);
          }
        });
      }
    }

    test('a live broadcast that is reconnecting reads as loading', () {
      // buildPlaybackState reports a failed connection as buffering, with
      // sound still wanted. The widget must not say the broadcast plays.
      expect(
        widgetPlaybackFor(
          session(AudioProcessingState.buffering, playing: true),
          item(kLiveIndex),
        ),
        const WidgetPlayback(WidgetPlayState.loading, WidgetSource.live),
      );
    });

    test('a session with no item yet falls back to live, as the handler does',
        () {
      expect(
        widgetPlaybackFor(
          session(AudioProcessingState.ready, playing: true),
          null,
        ),
        playingLive,
      );
    });

    test('an item the catalog does not know falls back to live', () {
      expect(
        widgetPlaybackFor(
          session(AudioProcessingState.ready, playing: true),
          const MediaItem(id: 'nope', title: 'x'),
        ),
        playingLive,
      );
    });

    test('the session the handler uses when nothing is engaged is idle', () {
      expect(widgetPlaybackFor(PlaybackState(), item(kLiveIndex)), idle);
    });
  });

  group('the stored value', () {
    test('names the state, the source, the time and who wrote it', () {
      final text = encodeWidgetPlayback(
        playingHukamnama,
        at: DateTime.fromMillisecondsSinceEpoch(1730000000000),
      );
      expect(jsonDecode(text), {
        'state': 'playing',
        'source': 'hukamnama',
        'at': 1730000000000,
        'by': 'app',
      });
    });

    test('idle has no source', () {
      final text = encodeWidgetPlayback(
        idle,
        at: DateTime.fromMillisecondsSinceEpoch(5),
      );
      expect((jsonDecode(text) as Map)['state'], 'idle');
      expect((jsonDecode(text) as Map)['source'], isNull);
    });

    test('Kotlin reads the words Dart writes', () {
      // The names are the contract with WidgetPlayback.kt.
      expect(WidgetPlayState.values.map((s) => s.name),
          ['idle', 'loading', 'playing', 'paused']);
      expect(WidgetSource.values.map((s) => s.name),
          ['live', 'hukamnama', 'katha']);
    });
  });

  group('the sync', () {
    late BehaviorSubject<PlaybackState> states;
    late BehaviorSubject<MediaItem?> items;
    late _Recorder recorder;
    late WidgetPlaybackSync sync;
    var clock = DateTime.fromMillisecondsSinceEpoch(1000);

    setUp(() {
      clock = DateTime.fromMillisecondsSinceEpoch(1000);
      // What the audio handler starts with: an idle session and no item.
      states = BehaviorSubject.seeded(PlaybackState());
      items = BehaviorSubject<MediaItem?>.seeded(null);
      recorder = _Recorder();
      sync = WidgetPlaybackSync(
        playbackState: states,
        mediaItem: items,
        publisher: recorder,
        now: () => clock,
      )..start();
    });

    tearDown(() async {
      sync.dispose();
      await states.close();
      await items.close();
    });

    Future<void> settle() => pumpEventQueue();

    void emit(
      AudioProcessingState processing, {
      bool playing = false,
      int? source,
    }) {
      if (source != null) items.add(item(source));
      states.add(session(processing, playing: playing));
    }

    test('writes nothing for the idle session the app starts with', () async {
      await settle();
      expect(recorder.writes, isEmpty);
    });

    test('follows a tap on live: loading, then playing', () async {
      emit(AudioProcessingState.loading, playing: true, source: kLiveIndex);
      await settle();
      emit(AudioProcessingState.ready, playing: true);
      await settle();

      expect(recorder.playbacks.map((p) => (p['state'], p['source'])), [
        ('loading', 'live'),
        ('playing', 'live'),
      ]);
    });

    test('follows a pause, a resume and a stop', () async {
      emit(AudioProcessingState.ready, playing: true, source: kMukhwakIndex);
      await settle();
      emit(AudioProcessingState.ready, playing: false);
      await settle();
      emit(AudioProcessingState.ready, playing: true);
      await settle();
      emit(AudioProcessingState.idle);
      await settle();

      expect(recorder.playbacks.map((p) => (p['state'], p['source'])), [
        ('playing', 'hukamnama'),
        ('paused', 'hukamnama'),
        ('playing', 'hukamnama'),
        ('idle', null),
      ]);
    });

    test('switching source while playing is a write of its own', () async {
      emit(AudioProcessingState.ready, playing: true, source: kLiveIndex);
      await settle();
      emit(AudioProcessingState.ready, playing: true, source: kMukhwakIndex);
      await settle();

      expect(recorder.playbacks.map((p) => p['source']), [
        'live',
        'hukamnama',
      ]);
    });

    test('a state the widget cannot tell apart is not written twice', () async {
      emit(AudioProcessingState.ready, playing: true, source: kLiveIndex);
      await settle();
      // Position updates and a rebuffer that settles change the session
      // without changing what the widget shows.
      states.add(PlaybackState(
        processingState: AudioProcessingState.ready,
        playing: true,
        updatePosition: const Duration(seconds: 9),
      ));
      await settle();

      expect(recorder.writes, hasLength(1));
    });

    test('stamps each write with the time it was made', () async {
      emit(AudioProcessingState.ready, playing: true, source: kLiveIndex);
      await settle();
      clock = DateTime.fromMillisecondsSinceEpoch(7000);
      emit(AudioProcessingState.idle);
      await settle();

      expect(recorder.playbacks.map((p) => p['at']), [1000, 7000]);
      expect(recorder.playbacks.map((p) => p['by']), ['app', 'app']);
    });

    test('writes only the playback key, so the text keeps what it has',
        () async {
      emit(AudioProcessingState.ready, playing: true, source: kLiveIndex);
      await settle();
      expect(recorder.writes.single.keys, [WidgetKeys.playback]);
    });

    test('stop returns the widget to idle', () async {
      emit(AudioProcessingState.ready, playing: true, source: kLiveIndex);
      await settle();
      emit(AudioProcessingState.idle);
      await settle();

      expect(recorder.playbacks.last['state'], 'idle');
      expect(recorder.playbacks.last['source'], isNull);
    });

    test('a slow write is followed by the newest state, not every state',
        () async {
      recorder.hold = true;
      emit(AudioProcessingState.loading, playing: true, source: kLiveIndex);
      await settle();
      // The first write is stuck. Two more states arrive behind it.
      emit(AudioProcessingState.ready, playing: true);
      emit(AudioProcessingState.ready, playing: false);
      await settle();

      recorder.hold = false;
      recorder.release();
      await settle();

      // The widget ends on the newest state, and never goes back in time.
      expect(recorder.playbacks.map((p) => p['state']).toList(), [
        'loading',
        'paused',
      ]);
    });

    test('a failed write does not stop the next one', () async {
      recorder.failNext = true;
      emit(AudioProcessingState.ready, playing: true, source: kLiveIndex);
      await settle();
      emit(AudioProcessingState.idle);
      await settle();

      expect(recorder.playbacks.single['state'], 'idle');
    });

    test('after dispose, nothing is written', () async {
      sync.dispose();
      emit(AudioProcessingState.ready, playing: true, source: kLiveIndex);
      await settle();
      expect(recorder.writes, isEmpty);
    });
  });
}
