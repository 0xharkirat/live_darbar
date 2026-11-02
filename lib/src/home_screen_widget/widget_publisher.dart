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
/// Android only for now. The iOS widget needs an App Group, which comes with
/// the Apple developer membership, and on any other platform there is no
/// launcher to ask.
class HomeWidgetPublisher implements WidgetPublisher {
  const HomeWidgetPublisher();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> publish(Map<String, String> data) async {
    if (!isSupported) return;
    try {
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: kWidgetProviderClass);
    } catch (e) {
      // The widget is a courtesy. A failed write must not reach the player.
      if (!kReleaseMode) debugPrint('[widget] could not publish: $e');
    }
  }
}

final widgetPublisherProvider = Provider<WidgetPublisher>(
  (ref) => const HomeWidgetPublisher(),
);
