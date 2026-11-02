import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/home_screen_widget/widget_publisher.dart';

/// How long the sync waits after a change before it writes.
///
/// The locale, the date and the Hukamnama all arrive within a second of
/// launch, one after another. Waiting this long writes them once. It also
/// stops the widget from showing English for a moment before the saved
/// Punjabi has loaded.
final widgetSyncSettleProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 400),
);

/// Keeps the home screen widget's text in step with the app.
///
/// It writes when the Sikh date, the Hukamnama or the language gives a new
/// value. Read it once, near the top of the app, and it stays alive.
///
/// Writes never overlap, and each one reads the providers at the moment it
/// runs. So the last write always holds the newest state, however the changes
/// arrive. A write that would repeat the last one is skipped.
final widgetSyncProvider = Provider<void>((ref) {
  final sync = _WidgetSync(ref);
  ref.onDispose(sync.dispose);
  sync.start();
});

class _WidgetSync {
  _WidgetSync(this._ref);

  final Ref _ref;

  Timer? _settle;
  bool _dirty = false;
  bool _running = false;
  bool _disposed = false;
  Map<String, String>? _last;

  void start() {
    void changed(Object? previous, Object? next) => _request();
    _ref.listen(sikhDateProvider, changed);
    _ref.listen(hukamnamaProvider, changed);
    _ref.listen(localeController, changed);
    _request();
  }

  void dispose() {
    _disposed = true;
    _settle?.cancel();
  }

  void _request() {
    if (_disposed) return;
    _dirty = true;
    _settle?.cancel();
    _settle = Timer(_ref.read(widgetSyncSettleProvider), () {
      if (!_running) unawaited(_drain());
    });
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_dirty && !_disposed) {
        _dirty = false;
        await _write();
      }
    } catch (e) {
      if (!kReleaseMode) debugPrint('[widget] sync failed: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _write() async {
    final language = widgetLanguage(_ref.read(localeController));
    await initializeDateFormatting(language);
    if (_disposed) return;

    final data = buildWidgetData(
      now: _ref.read(clockProvider)(),
      language: language,
      l10n: lookupAppLocalizations(Locale(language)),
      hukamnama: _ref.read(hukamnamaProvider).value,
    );
    if (mapEquals(data, _last)) return;
    await _ref.read(widgetPublisherProvider).publish(data);
    // After the write, so a write that failed is tried again on the next change.
    _last = data;
  }
}
