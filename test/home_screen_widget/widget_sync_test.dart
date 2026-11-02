import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/home_screen_widget/widget_publisher.dart';
import 'package:live_darbar/src/home_screen_widget/widget_sync.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

class _Recorder implements WidgetPublisher {
  final List<Map<String, String>> writes = [];
  bool failNext = false;

  @override
  Future<void> publish(Map<String, String> data) async {
    if (failNext) {
      failNext = false;
      throw StateError('launcher not ready');
    }
    writes.add(data);
  }
}

/// A Hukamnama controller whose text a test sets.
class _Text extends HukamnamaController {
  _Text(this.first);

  final Hukamnama first;

  @override
  Future<Hukamnama> build() async => first;

  void show(Hukamnama h) => state = AsyncData(h);

  void load() => state = const AsyncLoading<Hukamnama>();
}

class _Locale extends LocaleController {
  _Locale(this.first);

  final String first;

  @override
  String build() => first;

  @override
  Future<void> changeLocale(String locale) async => state = locale;
}

Hukamnama _recorded({DateTime? on}) {
  final h = Hukamnama.fromSgpc(
    jsonDecode(
      File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
    ) as Map<String, dynamic>,
  );
  if (on == null) return h;
  return Hukamnama(date: on, ang: h.ang, lines: h.lines);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final table = SangrandTable.fromJsonString(
    File('assets/data/sgpc_sangrands.json').readAsStringSync(),
  );

  // 10:00 IST on 2 November 2026.
  var now = DateTime.utc(2026, 11, 2, 4, 30);
  late _Recorder recorder;

  setUp(() {
    now = DateTime.utc(2026, 11, 2, 4, 30);
    recorder = _Recorder();
  });

  ProviderContainer launch({
    String locale = 'en',
    Hukamnama? text,
    Duration settle = Duration.zero,
  }) {
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(() => now),
      sangrandTableProvider.overrideWith((ref) async => table),
      hukamnamaProvider.overrideWith(() => _Text(text ?? _recorded())),
      localeController.overrideWith(() => _Locale(locale)),
      widgetPublisherProvider.overrideWithValue(recorder),
      widgetSyncSettleProvider.overrideWithValue(settle),
    ]);
    addTearDown(container.dispose);
    // Read the way the app does: once, and left alive.
    container.listen(widgetSyncProvider, (_, __) {});
    return container;
  }

  Future<void> settled() async {
    // Let the providers load, then the timers and the write run.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('writes the date and the Rahao line once the Hukamnama has loaded',
      () async {
    launch();
    await settled();

    final last = recorder.writes.last;
    expect(last[WidgetKeys.language], 'en');
    expect(
      (jsonDecode(last[WidgetKeys.dates]!) as Map)['2026-11-02'],
      '2 Nov',
    );
    expect(last[WidgetKeys.line], contains('ਰਹਾਉ'));
    expect(last[WidgetKeys.hukamnamaMeta], '2 Nov · Ang 668');
  });

  test('writes again when a newer Hukamnama arrives', () async {
    final container = launch(text: _recorded(on: DateTime.utc(2026, 11, 1)));
    await settled();
    expect(recorder.writes.last[WidgetKeys.hukamnamaMeta], startsWith('1 Nov'));

    (container.read(hukamnamaProvider.notifier) as _Text).show(_recorded());
    await settled();

    expect(recorder.writes.last[WidgetKeys.hukamnamaMeta], startsWith('2 Nov'));
  });

  test('does not write again when nothing the widget shows has changed',
      () async {
    final container = launch();
    await settled();
    final count = recorder.writes.length;

    // A refresh goes loading and then lands on the same text.
    final text = container.read(hukamnamaProvider.notifier) as _Text;
    text.load();
    await settled();
    text.show(_recorded());
    await settled();

    expect(recorder.writes.length, count);
  });

  test('writes in Punjabi when the language changes', () async {
    final container = launch();
    await settled();
    expect(recorder.writes.last[WidgetKeys.language], 'en');

    await container.read(localeController.notifier).changeLocale('pa');
    await settled();

    final last = recorder.writes.last;
    expect(last[WidgetKeys.language], 'pa');
    final labels = jsonDecode(last[WidgetKeys.labels]!) as Map;
    expect((labels['live'] as Map)['idle'], 'ਲਾਈਵ ਕੀਰਤਨ ਚਲਾਓ');
    expect(
      (jsonDecode(last[WidgetKeys.dates]!) as Map)['2026-11-02'],
      startsWith('੨ '),
    );
  });

  test('joins a burst of changes into one write', () async {
    final container = launch(settle: const Duration(milliseconds: 80));
    final text = container.read(hukamnamaProvider.notifier) as _Text;

    await Future<void>.delayed(const Duration(milliseconds: 10));
    text.load();
    text.show(_recorded(on: DateTime.utc(2026, 11, 1)));
    text.show(_recorded());
    await container.read(localeController.notifier).changeLocale('pa');

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(recorder.writes, hasLength(1));
    expect(recorder.writes.single[WidgetKeys.language], 'pa');
    expect(recorder.writes.single[WidgetKeys.hukamnamaMeta], startsWith('੨ '));
  });

  test('tries a failed write again on the next change', () async {
    recorder.failNext = true;
    final container = launch();
    await settled();
    expect(recorder.writes, isEmpty);

    await container.read(localeController.notifier).changeLocale('pa');
    await settled();

    expect(recorder.writes, hasLength(1));
    expect(recorder.writes.single[WidgetKeys.language], 'pa');
  });

  test('writes the new day after SGPC midnight', () async {
    final container = launch();
    await settled();
    expect(
      (jsonDecode(recorder.writes.last[WidgetKeys.dates]!) as Map).keys.first,
      '2026-11-02',
    );

    // 00:10 IST on 3 November. The provider invalidates itself at midnight;
    // here the test does what the timer does.
    now = DateTime.utc(2026, 11, 2, 18, 40);
    container.invalidate(sikhDateProvider);
    await settled();

    final dates =
        jsonDecode(recorder.writes.last[WidgetKeys.dates]!) as Map;
    expect(dates.keys.first, '2026-11-03');
    expect(dates['2026-11-03'], '3 Nov');
    // The Hukamnama is still the 2nd's. The widget says so by the day.
    expect(recorder.writes.last[WidgetKeys.hukamnamaMeta], startsWith('2 Nov'));
  });
}
