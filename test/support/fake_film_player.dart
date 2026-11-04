import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:live_darbar/src/views/widgets/demo_film.dart';

/// Stands in for the video player behind a film, and records what the film
/// asks of it.
class FakeFilmPlayer extends ChangeNotifier implements FilmPlayer {
  FakeFilmPlayer(this.asset);

  final String asset;

  /// Set to make [initialize] fail, as a film that cannot play does.
  Object? initializeError;

  /// Set to hold [initialize] until a test completes it.
  Completer<void>? initializeGate;

  var plays = 0;
  var pauses = 0;
  var initialized = false;
  var disposed = false;

  var _value = const FilmValue();

  @override
  FilmValue get value => _value;

  /// The player reports [v], as it does while a film runs.
  void report(FilmValue v) {
    _value = v;
    notifyListeners();
  }

  /// The film is at [seconds] and playing.
  void playAt(double seconds) => report(
        FilmValue(
          playing: true,
          position: Duration(microseconds: (seconds * 1e6).round()),
        ),
      );

  bool get playing => _value.playing;

  @override
  Future<void> initialize() async {
    await initializeGate?.future;
    if (initializeError != null) throw initializeError!;
    initialized = true;
  }

  @override
  Future<void> play() async {
    plays++;
    report(FilmValue(playing: true, position: _value.position));
  }

  @override
  Future<void> pause() async {
    pauses++;
    if (!disposed) report(FilmValue(position: _value.position));
  }

  @override
  Widget view() => const SizedBox(key: ValueKey('film-view'));

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }
}

/// The players that a film asked for, in order. Give [call] to
/// `filmPlayerFactoryProvider`.
class FakeFilmPlayers {
  FakeFilmPlayers({this.initializeError});

  /// Each player it makes fails to open with this.
  final Object? initializeError;

  final players = <FakeFilmPlayer>[];

  FakeFilmPlayer? get last => players.isEmpty ? null : players.last;

  FilmPlayer call(String asset) {
    final p = FakeFilmPlayer(asset)..initializeError = initializeError;
    players.add(p);
    return p;
  }
}
