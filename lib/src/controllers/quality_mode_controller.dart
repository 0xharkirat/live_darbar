import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The listener's live quality setting, saved across launches.
///
/// A UI reads it with `ref.watch(qualityModeProvider)` and changes it with
/// `ref.read(qualityModeProvider.notifier).set(mode)`. The audio controller
/// listens to the same provider, so a change takes effect on the stream that
/// is playing, with no further call.
///
/// The state is synchronous and starts as [QualityMode.automatic], then
/// switches to the saved value a few milliseconds later. [ready] completes
/// when that has happened. The audio controller waits for it before it opens
/// the stream, so a listener on Data Saver never downloads a warm-up buffer on
/// the high tier first.
class QualityModeController extends Notifier<QualityMode> {
  static const prefsKey = 'stream_quality_mode';

  /// Completes once the saved value has been applied. Never throws.
  late Future<void> ready;

  bool _chosen = false;

  @override
  QualityMode build() {
    ready = _load();
    return QualityMode.automatic;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // A choice made while the read was pending is newer than the file.
      if (_chosen || !ref.mounted) return;
      state = QualityMode.parse(prefs.getString(prefsKey));
    } catch (e) {
      // Storage can be unavailable, for example in a private browser window.
      // Playing on the default is better than failing to play.
      if (!kReleaseMode) debugPrint('[quality] could not read setting: $e');
    }
  }

  Future<void> set(QualityMode mode) async {
    _chosen = true;
    if (mode == state) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, mode.name);
    } catch (e) {
      if (!kReleaseMode) debugPrint('[quality] could not save setting: $e');
    }
  }
}

final qualityModeProvider =
    NotifierProvider<QualityModeController, QualityMode>(
  QualityModeController.new,
);
