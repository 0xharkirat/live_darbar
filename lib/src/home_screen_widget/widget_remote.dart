import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/home_screen_widget/widget_links.dart';
import 'package:live_darbar/src/home_screen_widget/widget_playback.dart';

/// The channel the iPhone widget's play buttons use. Its name is the one in
/// WidgetPlayHost.swift.
const kWidgetControlChannel = 'com.hsi.harki.live_darbar/widget_control';

/// Does what a widget button showed. The same switch as a tap on the widget's
/// link (`_handleWidgetLink` in main.dart), so the two cannot drift.
///
/// [WidgetTap.openReader] is not here: it needs a screen.
Future<void> runWidgetTap(WidgetTap tap, AudioController audio) {
  switch (tap) {
    case WidgetTap.playLive:
      return audio.play(kLiveIndex);
    case WidgetTap.stop:
      return audio.stop();
    case WidgetTap.playHukamnama:
      return audio.play(kMukhwakIndex);
    case WidgetTap.pause:
      return audio.pause();
    case WidgetTap.openReader:
      return Future<void>.value();
  }
}

/// Answers the iPhone widget's play buttons while the app is in the
/// background, with or without a screen.
///
/// On iOS 17 and newer, a button is an `AudioPlaybackIntent` that runs in the
/// app's process (WidgetPlayIntents.swift). The intent sends `tap` with the
/// button's name, `live` or `hukamnama`. This decides from the real player,
/// like every other tap ([widgetTapFor]), does it, and answers once the sound
/// has started or [settle] has run out. The system gives a background intent
/// only so long, and the sound must have started by then.
///
/// Native sends the tap before the handler exists on a cold start. It retries
/// while this answers "not implemented", so start listening only when the
/// media session is ready.
class WidgetRemote {
  WidgetRemote({
    required this.audio,
    required this.now,
    required this.playing,
    this.settle = const Duration(seconds: 8),
  });

  final AudioController audio;

  /// What the media session does now. The handler's playback state, through
  /// [widgetPlaybackFor].
  final WidgetPlayback Function() now;

  /// Whether sound is on, as the media session reports it.
  final Stream<bool> playing;

  /// How long a play may take to reach sound before the answer goes back.
  final Duration settle;

  MethodChannel? _channel;

  void start() {
    _channel = const MethodChannel(kWidgetControlChannel)
      ..setMethodCallHandler(_handle);
  }

  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
  }

  /// The tap [call] asks for, by the name of the button.
  Future<String?> _handle(MethodCall call) async {
    if (call.method != 'tap') throw MissingPluginException();
    final link = switch (call.arguments) {
      'live' => WidgetLink.live,
      'hukamnama' => WidgetLink.hukamnama,
      // The widget's other part opens a screen. It is a link, never a tap here.
      _ => throw PlatformException(
          code: 'bad_source',
          message: 'Unknown source: ${call.arguments}',
        ),
    };
    final before = now();
    final tap = widgetTapFor(link, before);
    if (!kReleaseMode) {
      debugPrint('[widget] intent tap: ${tap.name} (was $before)');
    }
    await runWidgetTap(tap, audio);
    if (tap == WidgetTap.playLive || tap == WidgetTap.playHukamnama) {
      await _untilSound();
    }
    return tap.name;
  }

  Future<void> _untilSound() async {
    try {
      await playing.firstWhere((on) => on).timeout(settle);
    } on TimeoutException {
      // The sound is still opening. The widget shows "loading" until it does.
    }
  }
}
