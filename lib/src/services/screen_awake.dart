import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the phone's screen on, for a page that is read with no touch.
///
/// The phone locks itself for privacy and for battery, so only the Hukamnama
/// reader asks for this, and only while it is open and in front. A page calls
/// [hold] when it appears and [release] when it goes. The screen stays on
/// until every page that held it has let go, because the reader can be opened
/// twice (from the player, over itself).
///
/// It never throws. A phone that cannot hold the screen (the web without
/// permission, a platform with no plugin) still reads the Hukamnama.
class ScreenAwake {
  ScreenAwake([Future<void> Function(bool enable)? toggle])
      : _toggle = toggle ?? _plugin;

  final Future<void> Function(bool enable) _toggle;
  int _holders = 0;

  static Future<void> _plugin(bool enable) =>
      WakelockPlus.toggle(enable: enable);

  void hold() {
    _holders++;
    if (_holders == 1) _apply(true);
  }

  void release() {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) _apply(false);
  }

  void _apply(bool enable) {
    unawaited(() async {
      try {
        await _toggle(enable);
      } catch (e) {
        debugPrint('Screen timeout not changed: $e');
      }
    }());
  }
}

final screenAwakeProvider = Provider<ScreenAwake>((ref) => ScreenAwake());
