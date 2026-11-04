import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/widgets/widget_setting.dart';

import '../support/app_harness.dart';
import '../support/fake_widget_install.dart';

/// The permanent "Home screen widget" row in About. It does what the card on
/// Home does, and says "Added" when the widget is on the home screen.
final _en = lookupAppLocalizations(const Locale('en'));
final _pa = lookupAppLocalizations(const Locale('pa'));

Future<void> _pumpAbout(
  WidgetTester tester, {
  String locale = 'en',
  FakeWidgetInstall? install,
}) async {
  await pumpApp(
    tester,
    locale: locale,
    initialRoute: AppRoutes.about,
    widgetInstall: install ?? FakeWidgetInstall(),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Finder get _row => find.byType(WidgetSetting);

void main() {
  testWidgets('shows the row, with what the widget does and an Add word', (
    tester,
  ) async {
    await _pumpAbout(tester);

    expect(find.text(_en.widget_setting_title), findsOneWidget);
    expect(find.text(_en.widget_setting_detail), findsOneWidget);
    expect(find.text(_en.widget_setting_add), findsOneWidget);
    expect(find.text(_en.widget_setting_added), findsNothing);
  });

  testWidgets('sits in the group of settings, after the language', (
    tester,
  ) async {
    await _pumpAbout(tester);

    final language = tester.getTopLeft(find.text(_en.language_tooltip)).dy;
    final widget = tester.getTopLeft(find.text(_en.widget_setting_title)).dy;
    final contact = tester.getTopLeft(find.text(_en.about_section_contact)).dy;
    expect(widget, greaterThan(language));
    expect(widget, lessThan(contact));
  });

  testWidgets('is not there where there are no home screen widgets', (
    tester,
  ) async {
    await _pumpAbout(tester, install: FakeWidgetInstall(supported: false));

    expect(_row, findsNothing);
    expect(find.text(_en.widget_setting_title), findsNothing);
  });

  testWidgets('a tap on Android asks the phone to pin the widget', (
    tester,
  ) async {
    final phone = FakeWidgetInstall();
    await _pumpAbout(tester, install: phone);

    await tester.tap(_row);
    await tester.pump(const Duration(seconds: 1));

    expect(phone.pinCount, 1);
    expect(find.text(_en.widget_steps_title), findsNothing);
  });

  testWidgets('after a Cancel in the dialog, the row still adds the widget', (
    tester,
  ) async {
    // The card on Home shows once. After a Cancel there, this row is the way
    // back, on any later visit.
    final phone = FakeWidgetInstall();
    await _pumpAbout(tester, install: phone);

    await tester.tap(_row);
    await tester.pump(const Duration(seconds: 1));
    final binding = tester.binding;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_en.widget_setting_add), findsOneWidget);
    expect(find.text(_en.widget_setting_added), findsNothing);

    await tester.tap(_row);
    await tester.pump(const Duration(seconds: 1));

    expect(phone.pinCount, 2);
  });

  testWidgets('a tap on Android with no pinning opens the steps', (
    tester,
  ) async {
    final phone = FakeWidgetInstall(pinSupported: false);
    await _pumpAbout(tester, install: phone);

    await tester.tap(_row);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(_en.widget_steps_title), findsOneWidget);
    expect(find.text(_en.widget_steps_android_find), findsOneWidget);
  });

  testWidgets('a tap on iPhone opens the steps with the picture', (
    tester,
  ) async {
    final phone = FakeWidgetInstall(iphone: true);
    await _pumpAbout(tester, install: phone);

    await tester.tap(_row);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(phone.pinCount, 0);
    expect(find.text(_en.widget_steps_title), findsOneWidget);
    expect(find.text(_en.widget_steps_iphone_add), findsOneWidget);
  });

  group('when the widget is on the home screen', () {
    testWidgets('says Added, with no Add word', (tester) async {
      await _pumpAbout(
        tester,
        install: FakeWidgetInstall(placementNow: WidgetPlacement.added),
      );

      expect(find.text(_en.widget_setting_added), findsOneWidget);
      expect(find.text(_en.widget_setting_add), findsNothing);
    });

    testWidgets('a tap does nothing, so no second widget is pinned', (
      tester,
    ) async {
      final phone = FakeWidgetInstall(placementNow: WidgetPlacement.added);
      await _pumpAbout(tester, install: phone);

      await tester.tap(_row);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(phone.pinCount, 0);
      expect(find.text(_en.widget_steps_title), findsNothing);
    });

    testWidgets('a screen reader hears the row, and Added as its value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpAbout(
        tester,
        install: FakeWidgetInstall(placementNow: WidgetPlacement.added),
      );

      final node = tester.getSemantics(find.bySemanticsLabel(
        '${_en.widget_setting_title}. ${_en.widget_setting_detail}',
      ));
      expect(node.value, _en.widget_setting_added);
      handle.dispose();
    });
  });

  testWidgets('the row finds out if the widget is there when About opens', (
    tester,
  ) async {
    final phone = FakeWidgetInstall();
    await _pumpAbout(tester, install: phone);

    expect(phone.placementCount, greaterThanOrEqualTo(1));
  });

  testWidgets('the row stays when the phone cannot say if it is added', (
    tester,
  ) async {
    await _pumpAbout(
      tester,
      install: FakeWidgetInstall()..placementError = StateError('no plugin'),
    );

    expect(find.text(_en.widget_setting_add), findsOneWidget);
  });

  testWidgets('is a target of at least 48 points', (tester) async {
    await _pumpAbout(tester);

    expect(tester.getSize(_row).height, greaterThanOrEqualTo(48));
  });

  testWidgets('Punjabi: words, and no letter spacing', (tester) async {
    await _pumpAbout(tester, locale: 'pa');

    for (final text in [
      _pa.widget_setting_title,
      _pa.widget_setting_detail,
      _pa.widget_setting_add,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
      final style = tester.widget<Text>(find.text(text)).style!;
      expect(style.letterSpacing ?? 0, 0, reason: text);
    }
    expect(AppType.tracking, isFalse);
  });
}
