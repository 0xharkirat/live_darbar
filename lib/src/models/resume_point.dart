/// Where a Mukhwak or Katha recording was when it was last heard.
///
/// A recording that drops mid-play has to reopen where it stopped. Without
/// this the player reloads the file at 0:00, and someone 20 minutes into a
/// Katha on a train hears it start over after every tunnel.
///
/// Pure Dart: the controller feeds it positions and the current time.
class ResumePoint {
  /// Past this age the position is not offered.
  ///
  /// The undated Mukhwak and Katha URLs hold a different recording every day.
  /// A position from last night means nothing in this morning's file.
  static const maxAge = Duration(hours: 3);

  /// Positions this close to the start are not worth a seek.
  static const _minUseful = Duration(seconds: 2);

  int _index = -1;
  Duration _position = Duration.zero;
  DateTime? _at;

  /// Source index the position belongs to, or -1.
  int get index => _index;

  void remember(int index, Duration position, DateTime now) {
    if (position.isNegative) return;
    _index = index;
    _position = position;
    _at = now;
  }

  /// Forget the position, so the next load starts from the beginning.
  ///
  /// For a stop, and for a recording that played to its end.
  void clear() {
    _index = -1;
    _position = Duration.zero;
    _at = null;
  }

  /// Where to start source [index], or null to start from the beginning.
  Duration? startFor(int index, DateTime now) {
    final at = _at;
    if (at == null || index != _index) return null;
    if (_position < _minUseful) return null;
    if (now.difference(at) > maxAge) return null;
    return _position;
  }
}
