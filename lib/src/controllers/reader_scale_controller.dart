import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How large the Hukamnama reader sets its text, remembered between visits.
///
/// Many listeners read Gurmukhi slowly, on a small phone, without their
/// glasses. The phone's own text size helps, but it scales the whole app; this
/// scales only the words being read.
class ReaderScaleController extends Notifier<double> {
  static const steps = [1.0, 1.15, 1.3, 1.5, 1.75];
  static const _key = 'reader_scale';

  @override
  double build() {
    _load();
    return steps.first;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null && steps.contains(saved)) state = saved;
  }

  bool get canGrow => state < steps.last;
  bool get canShrink => state > steps.first;

  Future<void> grow() => _step(1);
  Future<void> shrink() => _step(-1);

  Future<void> _step(int by) async {
    final i = (steps.indexOf(state) + by).clamp(0, steps.length - 1);
    state = steps[i];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, state);
  }
}

final readerScaleProvider = NotifierProvider<ReaderScaleController, double>(
  ReaderScaleController.new,
);
