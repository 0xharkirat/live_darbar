import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';

/// What the app needs from the phone to offer the home screen widget: whether
/// it is there, and a way to ask for it.
///
/// An interface, so the card's rules run in a test with no phone. The one real
/// implementation is [HomeWidgetInstall], and it is the only code that asks
/// `home_widget` about the widget being on the home screen.
abstract interface class WidgetInstall {
  /// Whether this platform has home screen widgets: Android and iPhone.
  bool get isSupported;

  /// Whether this is an iPhone. It has no call that adds a widget, so the app
  /// can only show the steps.
  bool get isIphone;

  /// Whether a Live Darbar widget is on the home screen now. Throws when the
  /// phone cannot say.
  Future<WidgetPlacement> placement();

  /// Asks Android to pin the widget. Android shows its own dialog and puts the
  /// widget on the home screen when the listener agrees.
  ///
  /// Returns false when the app has nothing to ask: on an iPhone, or on an
  /// Android launcher that cannot pin. The caller then shows the steps.
  Future<bool> requestPin();
}

/// Debug builds only: `--dart-define=DEMO_WIDGET_MANUAL=true` makes "Add
/// widget" open the steps sheet on Android, as on a launcher that cannot pin.
/// Most test phones can pin, so this is the only way to see that sheet there.
const kDemoWidgetManual = bool.fromEnvironment('DEMO_WIDGET_MANUAL');

/// `home_widget` on the phone.
class HomeWidgetInstall implements WidgetInstall {
  const HomeWidgetInstall({
    this.forceManual = kDemoWidgetManual && !kReleaseMode,
  });

  /// Never asks Android to pin, so the steps open. See [kDemoWidgetManual].
  /// A release build ignores the define.
  final bool forceManual;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get isIphone => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<WidgetPlacement> placement() async {
    final installed = await HomeWidget.getInstalledWidgets();
    return installed.any(isLiveDarbarWidget)
        ? WidgetPlacement.added
        : WidgetPlacement.absent;
  }

  @override
  Future<bool> requestPin() async {
    if (!isSupported || isIphone || forceManual) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: kWidgetProviderClass,
      );
      return true;
    } catch (e) {
      // A launcher that says yes and then fails is the same to the listener
      // as one that says no: the steps still work.
      if (!kReleaseMode) debugPrint('[widget] could not ask to pin: $e');
      return false;
    }
  }
}

/// Whether [info] is this app's widget.
///
/// An iPhone names the widget's `kind`. Android names the provider class, as
/// the full name or in the short form that `ComponentName.shortClassName`
/// gives (`.widget.LiveDarbarWidgetProvider`), so the check accepts any tail
/// of [kWidgetProviderClass] that starts at a dot.
@visibleForTesting
bool isLiveDarbarWidget(HomeWidgetInfo info) {
  if (info.iOSKind == kIosWidgetKind) return true;
  final name = info.androidClassName;
  if (name == null || name.isEmpty) return false;
  return name == kWidgetProviderClass ||
      (name.startsWith('.') && kWidgetProviderClass.endsWith(name));
}

final widgetInstallProvider = Provider<WidgetInstall>(
  (ref) => const HomeWidgetInstall(),
);
