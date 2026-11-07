import 'package:flutter/foundation.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:quick_actions/quick_actions.dart';

/// The long-press menu on the app icon, in the listener's language.
///
/// The types are the ids that `shortcutPlay` in main.dart routes on. Do not
/// change them: a shortcut already pinned to a home screen keeps its type.
List<ShortcutItem> quickActionItems(AppLocalizations l10n) {
  return <ShortcutItem>[
    ShortcutItem(type: 'live_kirtan', localizedTitle: l10n.live_kirtan),
    ShortcutItem(type: 'mukhwak', localizedTitle: l10n.mukhwak),
    ShortcutItem(type: 'mukhwak_katha', localizedTitle: l10n.mukhwak_katha),
  ];
}

/// Writes the menu one update at a time, so the latest language lands last.
///
/// Android runs each `setShortcutItems` call on its own executor, so two calls
/// in flight can finish out of order. This waits for the write in flight, then
/// writes only the newest items. Updates that arrive in between are dropped.
class QuickActionsWriter {
  QuickActionsWriter(this._write);

  final Future<void> Function(List<ShortcutItem> items) _write;
  List<ShortcutItem>? _latest;
  Future<void> _tail = Future<void>.value();

  /// Completes when this update, or a newer one, has been written.
  Future<void> update(List<ShortcutItem> items) {
    _latest = items;
    return _tail = _tail.then((_) => _flush());
  }

  Future<void> _flush() async {
    final items = _latest;
    if (items == null) return;
    _latest = null;
    try {
      await _write(items);
    } catch (e) {
      debugPrint('Quick actions: $e');
    }
  }
}
