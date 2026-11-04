import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:live_darbar/src/home_screen_widget/widget_actions.dart';

/// Opens the Hukamnama reader for a tap on the daily reminder.
///
/// A tap that starts the app from closed arrives before the first frame, when
/// the app has no navigator yet. [openHukamnamaReader] throws then, and the
/// widget's native side answers by trying again. A reminder has no native
/// side to do that, so this tries again itself, every [every], up to [tries]
/// times. That is 10 seconds by default, as long as the native retry.
///
/// Opening twice does not stack two readers; [openHukamnamaReader] sees the
/// first.
Future<void> openReaderFromReminder(
  NavigatorState? Function() navigator, {
  int tries = 40,
  Duration every = const Duration(milliseconds: 250),
  Route<void> Function()? route,
}) async {
  for (var i = 0; i < tries; i++) {
    try {
      if (route == null) {
        openHukamnamaReader(navigator());
      } else {
        openHukamnamaReader(navigator(), route: route);
      }
      return;
    } on PlatformException {
      await Future<void>.delayed(every);
    }
  }
}
