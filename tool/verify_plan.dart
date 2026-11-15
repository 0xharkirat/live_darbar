// Picks what tool/verify tests, from the paths a branch changed.
//
//   git diff --name-only <base> | dart tool/verify_plan.dart
//
// It prints 1 line for each decision:
//   full           run the whole suite
//   test <path>    run this test file (only when there is no `full` line)
//   screens        render the screens (only when there is no `full` line)
//
// The rules, in order:
//   1. A change to shared test code or to the package set (test/support,
//      test/fixtures, pubspec, analysis options, assets) runs the full suite.
//      Any test can depend on it.
//   2. Otherwise the run takes each changed test file, and each test file that
//      imports a changed lib file directly.
//   3. When that set is empty, the run takes the full suite.
//   4. A change to code the screens draw (views, core, home screen widget,
//      l10n, main.dart) also renders the screens, unless the full suite runs:
//      the full suite renders them already.
//
// Rule 2 follows direct imports only. A lib file that tests reach through
// another file is covered by the screens render for UI code, and by the full
// suite that CI and the factory gates run before a merge.
import 'dart:convert';
import 'dart:io';

/// What a verify run tests.
class VerifyPlan {
  const VerifyPlan.full()
      : full = true,
        tests = const [],
        screens = false;
  const VerifyPlan.filtered(this.tests, {required this.screens}) : full = false;

  final bool full;
  final List<String> tests;
  final bool screens;

  List<String> lines() => full
      ? const ['full']
      : [for (final t in tests) 'test $t', if (screens) 'screens'];
}

final _sharedTestCode = RegExp(
  r'^(test/(support|fixtures)/|pubspec\.(yaml|lock)$|analysis_options\.yaml$|assets/)',
);
final _testFile = RegExp(r'^test/.*_test\.dart$');
final _screensCode = RegExp(
  r'^lib/(ui/|src/(views|core|home_screen_widget)/|l10n/|main\.dart$)',
);
final _packageImport = RegExp(r'''package:live_darbar/([^'"]+\.dart)''');

/// The lib files that [testSource] imports by `package:live_darbar/` URI, as
/// repo paths such as `lib/src/core/clock.dart`.
Set<String> libImports(String testSource) => {
      for (final m in _packageImport.allMatches(testSource)) 'lib/${m[1]}',
    };

/// Plans a run for the [changed] repo paths. [testImports] maps each test
/// file to the lib files it imports.
VerifyPlan planVerify(
  Iterable<String> changed,
  Map<String, Set<String>> testImports,
) {
  final paths = changed.where((p) => p.isNotEmpty).toSet();
  if (paths.any(_sharedTestCode.hasMatch)) return const VerifyPlan.full();

  final tests = <String>{
    ...paths.where(_testFile.hasMatch),
    for (final entry in testImports.entries)
      if (entry.value.any(paths.contains)) entry.key,
  };
  if (tests.isEmpty) return const VerifyPlan.full();

  return VerifyPlan.filtered(
    tests.toList()..sort(),
    screens: paths.any(_screensCode.hasMatch),
  );
}

Future<void> main() async {
  final changed = await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .toList();
  final testImports = {
    for (final file in Directory('test').listSync(recursive: true))
      if (file is File && _testFile.hasMatch(file.path))
        file.path: libImports(file.readAsStringSync()),
  };
  planVerify(changed, testImports).lines().forEach(stdout.writeln);
}
