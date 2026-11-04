import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';

/// What the app asks `home_widget`, and how it reads the answers: where the
/// widget is, and the 2 calls that pin it on Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  late List<MethodCall> calls;

  /// Answers [handler] for the plugin's calls, and records them.
  void phone(Future<Object?> Function(MethodCall call) handler) {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('which widgets are Live Darbar\'s', () {
    test('an iPhone widget with the kind of this app', () {
      expect(
        isLiveDarbarWidget(HomeWidgetInfo(iOSKind: kIosWidgetKind)),
        isTrue,
      );
    });

    test('an iPhone widget of another kind is not', () {
      expect(isLiveDarbarWidget(HomeWidgetInfo(iOSKind: 'Other')), isFalse);
    });

    test('an Android widget with the full class name', () {
      expect(
        isLiveDarbarWidget(
            HomeWidgetInfo(androidClassName: kWidgetProviderClass)),
        isTrue,
      );
    });

    test('an Android widget with the short class name the phone gives', () {
      // ComponentName.shortClassName drops the package of the app.
      expect(
        isLiveDarbarWidget(
          HomeWidgetInfo(androidClassName: '.widget.LiveDarbarWidgetProvider'),
        ),
        isTrue,
      );
    });

    test('an Android widget of another class is not', () {
      expect(
        isLiveDarbarWidget(
          HomeWidgetInfo(androidClassName: '.widget.OtherProvider'),
        ),
        isFalse,
      );
      expect(isLiveDarbarWidget(HomeWidgetInfo()), isFalse);
    });

    test('a class that only ends alike is not', () {
      expect(
        isLiveDarbarWidget(
          HomeWidgetInfo(androidClassName: 'XLiveDarbarWidgetProvider'),
        ),
        isFalse,
      );
    });
  });

  group('where the widget is', () {
    test('added, when the phone lists a Live Darbar widget', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      phone((call) async => [
            {
              'widgetId': 7,
              'androidClassName': '.widget.LiveDarbarWidgetProvider',
              'label': 'Hukamnama and Live Kirtan',
            },
          ]);

      expect(
          await const HomeWidgetInstall().placement(), WidgetPlacement.added);
      expect(calls.single.method, 'getInstalledWidgets');
    });

    test('added on an iPhone, by the kind', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      phone((call) async => [
            {'family': 'systemMedium', 'kind': kIosWidgetKind},
          ]);

      expect(
          await const HomeWidgetInstall().placement(), WidgetPlacement.added);
    });

    test('absent, when the phone lists none', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      phone((call) async => <Object>[]);

      expect(
        await const HomeWidgetInstall().placement(),
        WidgetPlacement.absent,
      );
    });

    test('absent, when only another app\'s widget is listed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      phone((call) async => [
            {'widgetId': 3, 'androidClassName': '.other.Provider'},
          ]);

      expect(
        await const HomeWidgetInstall().placement(),
        WidgetPlacement.absent,
      );
    });
  });

  group('the platform', () {
    test('Android and iPhone have home screen widgets', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(const HomeWidgetInstall().isSupported, isTrue);
      expect(const HomeWidgetInstall().isIphone, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(const HomeWidgetInstall().isSupported, isTrue);
      expect(const HomeWidgetInstall().isIphone, isTrue);
    });

    test('other platforms have none', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(const HomeWidgetInstall().isSupported, isFalse);
    });
  });

  group('asking Android to pin the widget', () {
    test('asks if pinning works, then pins by the full class name', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      phone((call) async =>
          call.method == 'isRequestPinWidgetSupported' ? true : null);

      expect(await const HomeWidgetInstall().requestPin(), isTrue);

      expect(calls.map((c) => c.method), [
        'isRequestPinWidgetSupported',
        'requestPinWidget',
      ]);
      expect(
        (calls.last.arguments as Map)['qualifiedAndroidName'],
        kWidgetProviderClass,
      );
    });

    test('does not pin on a launcher that cannot', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      phone((call) async => false);

      expect(await const HomeWidgetInstall().requestPin(), isFalse);
      expect(calls.map((c) => c.method), ['isRequestPinWidgetSupported']);
    });

    test('says false when the launcher fails after saying yes', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      phone((call) async {
        if (call.method == 'isRequestPinWidgetSupported') return true;
        throw PlatformException(code: 'no');
      });

      expect(await const HomeWidgetInstall().requestPin(), isFalse);
    });

    test('an iPhone has no call to make', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      phone((call) async => true);

      expect(await const HomeWidgetInstall().requestPin(), isFalse);
      expect(calls, isEmpty);
    });

    test('the manual demo asks nothing, so the steps open', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      phone((call) async => true);

      expect(
        await const HomeWidgetInstall(forceManual: true).requestPin(),
        isFalse,
      );
      expect(calls, isEmpty);
    });

    test('the manual demo is off unless the debug build asks for it', () {
      expect(const HomeWidgetInstall().forceManual, kDemoWidgetManual);
      expect(kDemoWidgetManual, isFalse, reason: 'tests run with no defines');
    });
  });
}
