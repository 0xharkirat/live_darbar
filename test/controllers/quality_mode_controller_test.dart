import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/controllers/quality_mode_controller.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('starts on automatic when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container();
    expect(c.read(qualityModeProvider), QualityMode.automatic);
    await c.read(qualityModeProvider.notifier).ready;
    expect(c.read(qualityModeProvider), QualityMode.automatic);
  });

  test('loads the saved value and reports ready', () async {
    SharedPreferences.setMockInitialValues({
      QualityModeController.prefsKey: 'dataSaver',
    });
    final c = container();
    expect(c.read(qualityModeProvider), QualityMode.automatic);
    await c.read(qualityModeProvider.notifier).ready;
    expect(c.read(qualityModeProvider), QualityMode.dataSaver);
  });

  test('falls back to automatic on a value it does not know', () async {
    SharedPreferences.setMockInitialValues({
      QualityModeController.prefsKey: 'ludicrous',
    });
    final c = container();
    await c.read(qualityModeProvider.notifier).ready;
    expect(c.read(qualityModeProvider), QualityMode.automatic);
  });

  test('set updates the state and saves it', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container();
    final notifier = c.read(qualityModeProvider.notifier);
    await notifier.ready;

    await notifier.set(QualityMode.high);

    expect(c.read(qualityModeProvider), QualityMode.high);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(QualityModeController.prefsKey), 'high');
  });

  test('a saved choice survives a new container', () async {
    SharedPreferences.setMockInitialValues({});
    final first = container();
    await first.read(qualityModeProvider.notifier).set(QualityMode.dataSaver);

    final second = container();
    await second.read(qualityModeProvider.notifier).ready;
    expect(second.read(qualityModeProvider), QualityMode.dataSaver);
  });

  test('a choice made before the read finishes is not overwritten', () async {
    SharedPreferences.setMockInitialValues({
      QualityModeController.prefsKey: 'high',
    });
    final c = container();
    final notifier = c.read(qualityModeProvider.notifier);

    // Choose before the saved value has been read.
    await notifier.set(QualityMode.dataSaver);
    await notifier.ready;

    expect(c.read(qualityModeProvider), QualityMode.dataSaver);
  });

  test('listeners hear every change', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container();
    final seen = <QualityMode>[];
    c.listen(qualityModeProvider, (_, next) => seen.add(next));
    final notifier = c.read(qualityModeProvider.notifier);
    await notifier.ready;

    await notifier.set(QualityMode.high);
    await notifier.set(QualityMode.dataSaver);
    await notifier.set(QualityMode.dataSaver);

    expect(seen, [QualityMode.high, QualityMode.dataSaver]);
  });
}
