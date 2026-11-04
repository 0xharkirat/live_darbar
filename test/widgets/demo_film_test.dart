import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/views/widgets/demo_film.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../support/fake_film_player.dart';

/// The taps drawn over a film, and the player behind it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the taps', () {
    final films = {'iPhone': DemoFilm.iphone, 'Android': DemoFilm.android};

    for (final MapEntry(key: name, value: film) in films.entries) {
      group('of the $name film', () {
        test('are in order, on the film, and inside its screen', () {
          var last = -1.0;
          for (final m in film.marks) {
            expect(m.t, greaterThan(last), reason: 'in time order');
            last = m.endT;
            for (final v in [m.x, m.y, m.endX, m.endY]) {
              expect(v, inInclusiveRange(0, 1));
            }
          }
          expect(last, lessThan(film.seconds), reason: 'all before the film ends');
        });

        test('leave the dot time to reach the next tap', () {
          for (var i = 1; i < film.marks.length; i++) {
            final gap = film.marks[i].t - film.marks[i - 1].endT;
            expect(gap, greaterThanOrEqualTo(0.6),
                reason: 'the dot needs time to reach tap $i');
          }
        });

        test('put the dot on each tap at the moment of the tap', () {
          for (final m in film.marks) {
            final s = TapMarks.at(film, m.t);
            expect(s.x, closeTo(m.x, 0.001));
            expect(s.y, closeTo(m.y, 0.001));
            expect(s.ring, closeTo(0, 0.01), reason: 'the ring starts');
          }
        });

        test('send out a ring at each tap, and none long after', () {
          for (final m in film.marks) {
            expect(TapMarks.at(film, m.t + 0.2).ring, inExclusiveRange(0, 1));
          }
          // Between the 2nd and 3rd taps there is a moment with no ring.
          final a = film.marks[1];
          final b = film.marks[2];
          expect(TapMarks.at(film, (a.endT + b.t) / 2).ring, -1);
        });

        test('sink at a press and come back', () {
          for (final m in film.marks) {
            final down = TapMarks.at(film, m.t + 0.12 + m.hold / 2).press;
            expect(down, lessThan(0.9));
            expect(down, greaterThanOrEqualTo(0.86 - 1e-9));
            final up = TapMarks.at(film, m.endT + 0.4).press;
            expect(up, 1.0, reason: 'the finger is up again');
          }
        });

        test('glide between taps with an ease, and do not jump', () {
          final keys = TapMarks.path(film);
          for (var i = 1; i < keys.length; i++) {
            expect(keys[i][0], greaterThanOrEqualTo(keys[i - 1][0]));
          }
          final a = film.marks[0];
          final b = film.marks[1];
          final mid = TapMarks.at(film, (a.endT + b.t) / 2 + 0.2, keys);
          final from = Offset(a.endX, a.endY);
          final to = Offset(b.x, b.y);
          final p = Offset(mid.x, mid.y);
          expect((p - from).distance, lessThan((to - from).distance),
              reason: 'on its way');
          // A step of 1/60 s never moves the dot far, even in a swipe.
          var prev = TapMarks.at(film, 0, keys);
          for (var t = 1 / 60; t < film.seconds; t += 1 / 60) {
            final s = TapMarks.at(film, t, keys);
            expect((Offset(s.x, s.y) - Offset(prev.x, prev.y)).distance,
                lessThan(0.09));
            prev = s;
          }
        });

        test('fade in as the film starts and out before it loops', () {
          expect(TapMarks.at(film, 0).opacity, 0);
          expect(TapMarks.at(film, film.seconds).opacity, 0);
          expect(TapMarks.at(film, 1.5).opacity, 1);
          expect(TapMarks.at(film, film.seconds - 0.2).opacity,
              inExclusiveRange(0, 1));
        });
      });
    }

    test('hold at a press for a long press, and move through a drag', () {
      final drag = DemoFilm.android.marks.last;
      expect(drag.hold, greaterThan(1));
      final mid = TapMarks.at(DemoFilm.android, drag.t + drag.hold / 2);
      expect(mid.press, closeTo(0.86, 1e-9), reason: 'the finger stays down');
      expect(mid.y, lessThan(drag.y));
      expect(mid.y, greaterThan(drag.endY));
      final end = TapMarks.at(DemoFilm.android, drag.endT);
      expect(end.y, closeTo(drag.endY, 0.001));
    });
  });

  group('the view', () {
    Future<FakeFilmPlayers> pump(WidgetTester tester, {required bool active}) async {
      final films = FakeFilmPlayers();
      Widget app(bool on) => ProviderScope(
            overrides: [filmPlayerFactoryProvider.overrideWithValue(films.call)],
            child: MaterialApp(
              home: Scaffold(
                body: TickerMode(
                  enabled: on,
                  child: const DemoFilmView(film: DemoFilm.android, width: 172),
                ),
              ),
            ),
          );
      await tester.pumpWidget(app(active));
      await tester.pump();
      return films;
    }

    testWidgets('pauses when a route covers it, and plays when it is back', (
      tester,
    ) async {
      final films = await pump(tester, active: true);
      final player = films.last!;
      expect(player.playing, isTrue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [filmPlayerFactoryProvider.overrideWithValue(films.call)],
          child: const MaterialApp(
            home: Scaffold(
              body: TickerMode(
                enabled: false,
                child: DemoFilmView(film: DemoFilm.android, width: 172),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(player.playing, isFalse);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [filmPlayerFactoryProvider.overrideWithValue(films.call)],
          child: const MaterialApp(
            home: Scaffold(
              body: TickerMode(
                enabled: true,
                child: DemoFilmView(film: DemoFilm.android, width: 172),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(player.playing, isTrue);
      expect(films.players, hasLength(1), reason: 'the same player throughout');
    });

    testWidgets('is a fixed size, so the sheet does not move when it plays', (
      tester,
    ) async {
      final films = await pump(tester, active: true);
      final before = tester.getSize(find.byType(DemoFilmView));
      films.last!.playAt(1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(find.byType(DemoFilmView)), before);
    });
  });

  group('the player', () {
    late _Platform platform;
    setUp(() {
      platform = _Platform();
      VideoPlayerPlatform.instance = platform;
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('opens the asset, muted and looped', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final player = VideoFilmPlayer(DemoFilm.iphone.video);
      await player.initialize();

      expect(platform.created.single.asset, DemoFilm.iphone.video);
      expect(platform.calls, containsAllInOrder(['looping true', 'volume 0.0']));
      await player.dispose();
    });

    test('plays, pauses and reports', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final player = VideoFilmPlayer(DemoFilm.iphone.video);
      await player.initialize();
      var heard = 0;
      player.addListener(() => heard++);

      await player.play();
      expect(player.value.playing, isTrue);
      await player.pause();
      expect(player.value.playing, isFalse);
      expect(heard, greaterThan(0));
      await player.dispose();
    });

    test('leaves the audio session of an iPhone alone', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final player = VideoFilmPlayer(DemoFilm.iphone.video);
      await player.initialize();

      expect(platform.calls.where((c) => c.startsWith('mix')), isEmpty,
          reason: 'any value would set the category of the whole app');
      await player.dispose();
    });

    test('mixes with the kirtan on Android, which asks for audio focus', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final player = VideoFilmPlayer(DemoFilm.android.video);
      await player.initialize();

      expect(platform.calls, contains('mix true'));
      await player.dispose();
    });

    test('says so when the film cannot open', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      platform.failToCreate = true;
      final player = VideoFilmPlayer(DemoFilm.iphone.video);

      await expectLater(player.initialize(), throwsA(anything));
      await player.dispose();
    });
  });
}

/// Stands in for the platform behind `video_player`, and records its calls.
class _Platform extends VideoPlayerPlatform with MockPlatformInterfaceMixin {
  final created = <DataSource>[];
  final calls = <String>[];
  var failToCreate = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created.add(options.dataSource);
    return 1;
  }

  /// The film is ready as soon as the player listens.
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => failToCreate
      // A film that the phone cannot decode: the platform says so as an error.
      ? Stream.error(PlatformException(code: 'VideoError', message: 'no codec'))
      : Stream.value(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 20),
            size: const Size(540, 1174),
          ),
        );

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      calls.add('looping $looping');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('volume $volume');

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async =>
      calls.add('mix $mixWithOthers');

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Widget buildView(int playerId) => const SizedBox();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}
