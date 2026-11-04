import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/home_screen_widget/widget_playback.dart';
import 'package:live_darbar/src/home_screen_widget/widget_remote.dart';

/// The calls the widget's intent makes, by hand. The real controller needs a
/// platform player.
class _Audio extends Fake implements AudioController {
  final calls = <String>[];

  @override
  Future<void> play([int index = kLiveIndex]) async => calls.add('play $index');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Audio audio;
  late WidgetPlayback now;
  late StreamController<bool> playing;
  late WidgetRemote remote;

  Future<Object?> tap(Object? argument, {String method = 'tap'}) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final reply = await messenger.handlePlatformMessage(
      kWidgetControlChannel,
      const StandardMethodCodec()
          .encodeMethodCall(MethodCall(method, argument)),
      null,
    );
    // No reply is what native sees as "not implemented".
    if (reply == null) throw MissingPluginException();
    return const StandardMethodCodec().decodeEnvelope(reply);
  }

  setUp(() {
    audio = _Audio();
    now = WidgetPlayback.idle;
    playing = StreamController<bool>.broadcast();
    remote = WidgetRemote(
      audio: audio,
      now: () => now,
      playing: playing.stream,
      settle: const Duration(milliseconds: 50),
    )..start();
  });

  tearDown(() {
    remote.dispose();
    unawaited(playing.close());
  });

  test('Live Kirtan plays when nothing plays', () async {
    await tap('live');
    expect(audio.calls, ['play $kLiveIndex']);
  });

  test('Live Kirtan stops when it plays', () async {
    now = const WidgetPlayback(WidgetPlayState.playing, WidgetSource.live);
    await tap('live');
    expect(audio.calls, ['stop']);
  });

  test('a second tap on Live Kirtan while it opens cancels it', () async {
    now = const WidgetPlayback(WidgetPlayState.loading, WidgetSource.live);
    await tap('live');
    expect(audio.calls, ['stop']);
  });

  test('the Hukamnama plays, then pauses', () async {
    await tap('hukamnama');
    now = const WidgetPlayback(WidgetPlayState.playing, WidgetSource.hukamnama);
    await tap('hukamnama');
    expect(audio.calls, ['play $kMukhwakIndex', 'pause']);
  });

  test('a play answers once the sound is on', () async {
    var answered = false;
    final reply = tap('live').then((_) => answered = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(answered, isFalse, reason: 'the sound is not on yet');
    playing.add(true);
    await reply;
    expect(answered, isTrue);
  });

  test('a play that never reaches sound still answers', () async {
    await tap('live');
    expect(audio.calls, ['play $kLiveIndex']);
  });

  test('the answer names what was done', () async {
    expect(await tap('live'), 'playLive');
    now = const WidgetPlayback(WidgetPlayState.playing, WidgetSource.live);
    expect(await tap('live'), 'stop');
  });

  test('a name that is not a button plays nothing', () async {
    await expectLater(tap('open'), throwsA(isA<PlatformException>()));
    await expectLater(tap(null), throwsA(isA<PlatformException>()));
    expect(audio.calls, isEmpty);
  });

  test('any other method is not implemented', () async {
    await expectLater(
      tap('live', method: 'play'),
      throwsA(isA<MissingPluginException>()),
    );
    expect(audio.calls, isEmpty);
  });
}
