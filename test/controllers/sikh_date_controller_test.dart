import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

SangrandTable shippedTable() => SangrandTable.fromJsonString(
      File('assets/data/sgpc_sangrands.json').readAsStringSync(),
    );

ProviderContainer containerAt(DateTime instant, {SangrandTable? table}) {
  final container = ProviderContainer(overrides: [
    clockProvider.overrideWithValue(() => instant),
    if (table != null) sangrandTableProvider.overrideWith((ref) async => table),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sikhDateProvider', () {
    test('answers for SGPC\'s day, not the phone\'s', () async {
      // 19:00 UTC on 1 November is 00:30 IST on 2 November at Amritsar, and
      // 06:00 on 2 November in Sydney. The Sikh date is the Amritsar one.
      final container =
          containerAt(DateTime.utc(2026, 11, 1, 19, 0), table: shippedTable());
      final date = await container.read(sikhDateProvider.future);
      expect(date!.day, 17);
      expect(date.monthEnglish, 'Katak');
      expect(date.gregorian, DateTime.utc(2026, 11, 2));
    });

    test('still the previous day at 23:59 IST', () async {
      // 18:29 UTC is 23:59 IST on 1 November.
      final container =
          containerAt(DateTime.utc(2026, 11, 1, 18, 29), table: shippedTable());
      final date = await container.read(sikhDateProvider.future);
      expect(date!.day, 16);
      expect(date.gregorian, DateTime.utc(2026, 11, 1));
    });

    test('moves to the next day by itself at midnight in India', () async {
      // One second before the 2nd begins at Amritsar.
      var now = DateTime.utc(2026, 11, 1, 18, 29, 59);
      final container = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(() => now),
        sangrandTableProvider.overrideWith((ref) async => shippedTable()),
      ]);
      addTearDown(container.dispose);

      final days = <int?>[];
      container.listen(
        sikhDateProvider,
        (_, next) => days.add(next.value?.day),
        fireImmediately: true,
      );
      expect((await container.read(sikhDateProvider.future))!.day, 16);

      now = DateTime.utc(2026, 11, 1, 18, 30, 1);
      final end = DateTime.now().add(const Duration(seconds: 6));
      while (container.read(sikhDateProvider).value?.day != 17) {
        expect(DateTime.now().isBefore(end), isTrue,
            reason: 'the provider never moved on; saw $days');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(container.read(sikhDateProvider).value!.gregorian,
          DateTime.utc(2026, 11, 2));
    });

    test('is null for a day outside the table', () async {
      final container =
          containerAt(DateTime.utc(2035, 1, 1), table: shippedTable());
      expect(await container.read(sikhDateProvider.future), isNull);
    });

    test('is null when the table could not be loaded', () async {
      final container = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 2)),
        sangrandTableProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(container.dispose);
      expect(await container.read(sikhDateProvider.future), isNull);
    });
  });

  group('sangrandTableProvider', () {
    test('loads the bundled asset', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final table = await container.read(sangrandTableProvider.future);
      expect(table, isNotNull);
      expect(table!.firstDay, DateTime.utc(2025, 3, 14));
      expect(table.endExclusive.year, greaterThanOrEqualTo(2029));
    });

    test('is null, not an error, when the asset is missing', () async {
      rootBundle.evict(kSangrandAsset);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async => null);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
        rootBundle.evict(kSangrandAsset);
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(sangrandTableProvider.future), isNull);
    });
  });

  group('untilNextSgpcDay', () {
    test('counts to the next midnight in India', () {
      // 18:00 UTC is 23:30 IST, so 30 minutes remain, plus the 1 s margin.
      final left = untilNextSgpcDay(DateTime.utc(2026, 11, 1, 18, 0));
      expect(left, const Duration(minutes: 30, seconds: 1));
    });

    test('is almost a whole day just after midnight in India', () {
      // 18:30 UTC is exactly 00:00 IST.
      final left = untilNextSgpcDay(DateTime.utc(2026, 11, 1, 18, 30));
      expect(left, const Duration(hours: 24, seconds: 1));
    });

    test('crosses a month end', () {
      // 30 November 12:00 UTC is 17:30 IST, 6.5 hours before 1 December.
      final left = untilNextSgpcDay(DateTime.utc(2026, 11, 30, 12, 0));
      expect(left, const Duration(hours: 6, minutes: 30, seconds: 1));
    });
  });
}
