import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_plan.dart';

void main() {
  const imports = {
    'test/controllers/now_playing_test.dart': {
      'lib/src/controllers/now_playing_controller.dart',
    },
    'test/core/motion_test.dart': {'lib/src/core/motion.dart'},
    'test/widgets/pressable_test.dart': {
      'lib/src/views/widgets/pressable.dart',
    },
  };

  test('reads package imports as repo paths', () {
    expect(
      libImports(
        "import 'package:live_darbar/src/core/clock.dart';\n"
        'import "package:live_darbar/l10n/app_localizations.dart";\n'
        "import 'package:flutter/material.dart';\n",
      ),
      {'lib/src/core/clock.dart', 'lib/l10n/app_localizations.dart'},
    );
  });

  test('runs the full suite when nothing maps to a test', () {
    expect(planVerify(['AGENTS.md', 'tool/verify'], imports).lines(), [
      'full',
    ]);
    expect(planVerify([], imports).lines(), ['full']);
  });

  test('runs the full suite when shared test code or packages change', () {
    for (final shared in [
      'test/support/app_harness.dart',
      'test/fixtures/release_forced.json',
      'pubspec.yaml',
      'pubspec.lock',
      'analysis_options.yaml',
      'assets/images/x.png',
    ]) {
      expect(
        planVerify([shared, 'test/core/motion_test.dart'], imports).full,
        isTrue,
        reason: shared,
      );
    }
  });

  test('adds the tests that import a changed lib file to a touched test', () {
    final plan = planVerify([
      'lib/src/controllers/now_playing_controller.dart',
      'test/core/motion_test.dart',
    ], imports);
    expect(plan.full, isFalse);
    expect(plan.tests, [
      'test/controllers/now_playing_test.dart',
      'test/core/motion_test.dart',
    ]);
    expect(plan.screens, isFalse);
  });

  test('renders the screens for code the screens draw', () {
    for (final ui in [
      'lib/src/views/widgets/pressable.dart',
      'lib/src/core/motion.dart',
      'lib/l10n/app_en.arb',
      'lib/main.dart',
      'lib/src/home_screen_widget/widget_data.dart',
    ]) {
      final plan = planVerify([ui, 'test/core/motion_test.dart'], imports);
      expect(plan.screens, isTrue, reason: ui);
      expect(plan.lines().last, 'screens', reason: ui);
    }
  });

  test('leaves the screens to the full suite', () {
    final plan = planVerify(['lib/src/views/screens/home_screen.dart'], {});
    expect(plan.lines(), ['full']);
  });
}
