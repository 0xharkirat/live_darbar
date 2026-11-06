import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/views/widgets/update_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hark, 6 November: "we also need a check for update", in About, which looks
/// for a newer version when the listener asks.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  /// release.json with Android at [build].
  Map<String, dynamic> manifest(int build) => {
        'android': {'version': '3.$build.0', 'build': build},
        'ios': {'version': '3.$build.0', 'build': build},
        'stores': {'android': 'x', 'ios': 'x'},
        'notes': {
          'en': ['Something new'],
          'pa': ['ਕੁਝ ਨਵਾਂ'],
        },
      };

  /// [answers] is what the release file says at each read, in order.
  Future<List<int>> pump(
    WidgetTester tester,
    List<Map<String, dynamic>?> answers,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final reads = <int>[0];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentBuildProvider.overrideWith((ref) async => 11),
          appVersionProvider.overrideWith((ref) async => '3.1.0 (11)'),
          releaseManifestProvider.overrideWith((ref) async {
            final answer = answers[reads.first.clamp(0, answers.length - 1)];
            reads.first++;
            return answer;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.material,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: UpdateSetting()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return reads;
  }

  testWidgets('shows the version before any check', (tester) async {
    await pump(tester, [manifest(11)]);
    expect(find.text(en.update_check_title), findsOneWidget);
    expect(find.text(en.update_version('3.1.0 (11)')), findsOneWidget);
  });

  testWidgets('says so when this is the newest version', (tester) async {
    await pump(tester, [manifest(11)]);
    await tester.tap(find.text(en.update_check_title));
    await tester.pumpAndSettle();
    expect(find.text(en.update_check_latest('3.1.0 (11)')), findsOneWidget);
  });

  testWidgets('reads the release file again at the tap, not the old copy', (
    tester,
  ) async {
    // At launch nothing was newer. By the tap, build 12 is out.
    final reads = await pump(tester, [manifest(11), manifest(12)]);
    expect(reads.first, 0, reason: 'the row reads nothing until a tap');
    // The launch read, as the update offer makes it.
    await ProviderScope.containerOf(tester.element(find.byType(UpdateSetting)))
        .read(releaseManifestProvider.future);
    expect(reads.first, 1);

    await tester.tap(find.text(en.update_check_title));
    await tester.pumpAndSettle();

    expect(find.text(en.update_available), findsOneWidget);
    expect(find.text('Something new'), findsOneWidget);
  });

  testWidgets('says it could not check when the file cannot be read', (
    tester,
  ) async {
    await pump(tester, [null]);
    await tester.tap(find.text(en.update_check_title));
    await tester.pumpAndSettle();
    expect(find.text(en.update_check_failed), findsOneWidget);
  });
}
