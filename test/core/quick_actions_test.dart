import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/quick_actions.dart';
import 'package:quick_actions/quick_actions.dart';

/// The long-press menu on the app icon, in English and Punjabi.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final pa = lookupAppLocalizations(const Locale('pa'));

  test('the types stay the same, in order', () {
    for (final l10n in [en, pa]) {
      expect(
        quickActionItems(l10n).map((item) => item.type),
        ['live_kirtan', 'mukhwak', 'mukhwak_katha'],
      );
    }
  });

  test('the titles are the English strings', () {
    expect(
      quickActionItems(en).map((item) => item.localizedTitle),
      [en.live_kirtan, en.mukhwak, en.mukhwak_katha],
    );
  });

  test('the titles are the Punjabi strings', () {
    final titles = quickActionItems(pa).map((item) => item.localizedTitle);
    expect(titles, [pa.live_kirtan, pa.mukhwak, pa.mukhwak_katha]);
    expect(titles, isNot(quickActionItems(en).map((i) => i.localizedTitle)));
  });

  group('QuickActionsWriter', () {
    List<String?> titles(List<ShortcutItem> items) =>
        items.map((item) => item.localizedTitle).toList();

    test('the newest language lands last when the first write is slow',
        () async {
      final firstWrite = Completer<void>();
      final written = <List<ShortcutItem>>[];
      final writer = QuickActionsWriter((items) {
        written.add(items);
        return written.length == 1 ? firstWrite.future : Future<void>.value();
      });

      final first = writer.update(quickActionItems(en));
      await Future<void>.delayed(Duration.zero);
      final second = writer.update(quickActionItems(pa));
      await Future<void>.delayed(Duration.zero);
      expect(written, hasLength(1), reason: 'waits for the write in flight');

      firstWrite.complete();
      await Future.wait([first, second]);
      expect(written, hasLength(2));
      expect(titles(written.last), titles(quickActionItems(pa)));
    });

    test('skips the updates it was too busy to write', () async {
      final firstWrite = Completer<void>();
      final written = <List<ShortcutItem>>[];
      final writer = QuickActionsWriter((items) {
        written.add(items);
        return written.length == 1 ? firstWrite.future : Future<void>.value();
      });

      writer.update(quickActionItems(en));
      await Future<void>.delayed(Duration.zero);
      writer.update(quickActionItems(pa));
      final last = writer.update(quickActionItems(en));
      firstWrite.complete();
      await last;
      expect(written, hasLength(2));
      expect(titles(written.last), titles(quickActionItems(en)));
    });

    test('keeps writing after a failed write', () async {
      var calls = 0;
      final writer = QuickActionsWriter((items) async {
        if (++calls == 1) throw StateError('no plugin');
      });

      await writer.update(quickActionItems(en));
      await writer.update(quickActionItems(pa));
      expect(calls, 2);
    });
  });
}
