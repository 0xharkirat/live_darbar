import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';

/// Where the widget's text goes. A seam, so a test can watch what is written.
abstract class WidgetPublisher {
  /// Stores [data] and asks the launcher to draw the widget again.
  ///
  /// Keys that are not in [data] keep the value they have.
  Future<void> publish(Map<String, String> data);
}

/// Writes through `home_widget`, which owns the shared store on each platform.
///
/// Android and iPhone. On iPhone the store is the App Group's, because the
/// widget runs in its own process. On any other platform there is no launcher
/// to ask.
class HomeWidgetPublisher implements WidgetPublisher {
  const HomeWidgetPublisher();

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Points `home_widget` at the App Group on iPhone. Call it once, before
  /// the first [publish]. Without it, every write on iPhone fails.
  static Future<void> prepare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await HomeWidget.setAppGroupId(kIosAppGroupId);
    } catch (e) {
      if (!kReleaseMode) debugPrint('[widget] no App Group: $e');
    }
  }

  @override
  Future<void> publish(Map<String, String> data) async {
    if (!isSupported) return;
    try {
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName: kWidgetProviderClass,
        iOSName: kIosWidgetKind,
      );
    } catch (e) {
      // The widget is a courtesy. A failed write must not reach the player.
      if (!kReleaseMode) debugPrint('[widget] could not publish: $e');
    }
  }
}

final widgetPublisherProvider = Provider<WidgetPublisher>(
  (ref) => const HomeWidgetPublisher(),
);
