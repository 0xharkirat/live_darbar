/// What the home screen widget says about playback, and the code that keeps it
/// true.
///
/// The widget shares the player's state. The media session is the one place
/// that every way of playing meets: the app, the notification, a headset, the
/// car and the widget itself all end in `LiveDarbarAudioHandler`. So the widget
/// listens there, to the handler's playback state, and not to the app's
/// screens. Whatever changes playback, the widget hears it.
///
/// The widget is drawn by the launcher, outside this process. This file only
/// writes the state to the shared store. `WidgetPlayback.kt` reads it back,
/// and it decides what to draw and what to trust. In particular, it ignores a
/// state written before its process started, because the session that wrote
/// it is gone. See `WidgetPlayback.reconcile`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart'
    show AudioProcessingState, MediaItem, PlaybackState;
import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/home_screen_widget/widget_publisher.dart';
import 'package:live_darbar/src/media_session/voice_query.dart';
import 'package:live_darbar/src/models/source_index.dart';
import 'package:rxdart/rxdart.dart';

/// What the player is doing, in the five words the widget has for it.
///
/// "Idle" is the fifth: nothing is playing and nothing is wanted. The
/// names are the strings in the store, and Kotlin reads the same ones.
enum WidgetPlayState {
  /// No session. The widget offers to play.
  idle,

  /// Sound is wanted and has not started: a source is opening, or the live
  /// stream is reconnecting.
  loading,

  /// Sound is on.
  playing,

  /// A session exists and sound is off. The notification is still there.
  paused,
}

/// Which source the session has, by the names the widget uses.
///
/// The order is the order of [kSourceIndexes], so a source index is also an
/// index into [values].
enum WidgetSource { live, hukamnama, katha }

/// The playback the widget shows: a state, and the source it belongs to.
@immutable
class WidgetPlayback {
  const WidgetPlayback(this.state, [this.source])
      : assert(
          (state == WidgetPlayState.idle) == (source == null),
          'idle has no source, and everything else has one',
        );

  /// Nothing playing.
  static const idle = WidgetPlayback(WidgetPlayState.idle);

  final WidgetPlayState state;

  /// Null only when [state] is [WidgetPlayState.idle].
  final WidgetSource? source;

  @override
  bool operator ==(Object other) =>
      other is WidgetPlayback && other.state == state && other.source == source;

  @override
  int get hashCode => Object.hash(state, source);

  @override
  String toString() => 'WidgetPlayback(${state.name}, ${source?.name})';
}

/// The widget's playback for the media session's [state] and current [item].
///
/// This is the whole mapping, and every processing state is in it:
///
/// | session                      | widget  |
/// | ---------------------------- | ------- |
/// | idle, completed, error       | idle    |
/// | loading or buffering, sound wanted | loading |
/// | loading or buffering, no sound wanted | paused |
/// | ready, playing               | playing |
/// | ready, not playing           | paused  |
///
/// The handler never reports `error`, because a retry that is under way is not
/// an error, but a state that cannot be read as playing is read as idle. A
/// recording that ran to its end is idle too: nothing is left to resume.
///
/// The source comes from the item's id, with live as the answer to anything
/// unknown, which is how the handler itself reads an id.
WidgetPlayback widgetPlaybackFor(PlaybackState state, MediaItem? item) {
  final phase = switch (state.processingState) {
    AudioProcessingState.idle ||
    AudioProcessingState.completed ||
    AudioProcessingState.error =>
      WidgetPlayState.idle,
    AudioProcessingState.loading ||
    AudioProcessingState.buffering =>
      state.playing ? WidgetPlayState.loading : WidgetPlayState.paused,
    AudioProcessingState.ready =>
      state.playing ? WidgetPlayState.playing : WidgetPlayState.paused,
  };
  if (phase == WidgetPlayState.idle) return WidgetPlayback.idle;
  return WidgetPlayback(phase, WidgetSource.values[_indexOf(item)]);
}

int _indexOf(MediaItem? item) =>
    item == null ? kLiveIndex : sourceForMediaId(item.id);

/// The text that goes in the store under [WidgetKeys.playback].
///
/// One key, so the state and its source can never be read half written.
/// [at] is when the state was true. Kotlin compares it with the start of its
/// own process, and a state from before that is not believed.
String encodeWidgetPlayback(WidgetPlayback playback, {required DateTime at}) =>
    jsonEncode({
      'state': playback.state.name,
      'source': playback.source?.name,
      'at': at.millisecondsSinceEpoch,
      // The widget writes the same key when a tap starts a source, before the
      // app has woken. "By" says which of the two wrote it.
      'by': 'app',
    });

/// Writes the widget's playback state each time the media session changes.
///
/// Start it once, with the handler's two streams, as soon as the handler
/// exists. It starts out believing the session is idle, because the handler
/// does, so the first idle state writes nothing. That matters on a cold start
/// from the widget: the widget has already written "loading", and an "idle"
/// from an app that has not yet been told to play would undo it.
///
/// A write is one state, whole. If the store is slow, the writes that pile up
/// behind it collapse into the newest, so the widget never ends on an old
/// state.
class WidgetPlaybackSync {
  WidgetPlaybackSync({
    required this.playbackState,
    required this.mediaItem,
    required this.publisher,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Stream<PlaybackState> playbackState;
  final Stream<MediaItem?> mediaItem;
  final WidgetPublisher publisher;
  final DateTime Function() _now;

  StreamSubscription<WidgetPlayback>? _subscription;

  /// The newest state the session reported.
  WidgetPlayback _desired = WidgetPlayback.idle;

  /// The state the store holds, as far as this class knows. Null after a
  /// write failed, so that the next change writes even if it looks the same.
  WidgetPlayback? _written = WidgetPlayback.idle;

  bool _writing = false;
  bool _disposed = false;

  void start() {
    _subscription ??= Rx.combineLatest2<PlaybackState, MediaItem?,
        WidgetPlayback>(playbackState, mediaItem, widgetPlaybackFor).listen(
      _changed,
    );
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _changed(WidgetPlayback next) {
    if (_disposed) return;
    _desired = next;
    if (!_writing) unawaited(_drain());
  }

  Future<void> _drain() async {
    _writing = true;
    try {
      while (!_disposed && _desired != _written) {
        final next = _desired;
        try {
          await publisher.publish({
            WidgetKeys.playback: encodeWidgetPlayback(next, at: _now()),
          });
          _written = next;
        } catch (e) {
          // The widget is a courtesy. The next change tries again.
          if (!kReleaseMode) debugPrint('[widget] playback not written: $e');
          _written = null;
          break;
        }
      }
    } finally {
      _writing = false;
    }
  }
}
