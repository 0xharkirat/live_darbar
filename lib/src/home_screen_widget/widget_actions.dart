import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';

/// The commands the home screen widget and the voice assistant send the app.
///
/// [kOpenHukamnamaCommand] is a tap on the widget away from its buttons.
/// MainActivity.kt turns the widget's fixed intent action into it
/// (`WidgetActions.commandFor`) and sends it down the OACP channel, which
/// retries until the app is ready.
///
/// The widget's two buttons, which play, pause and stop, are not here. They go to
/// the media session natively, with no screen. See `WidgetControl` in
/// WidgetControlReceiver.kt.
///
/// [kPlayLiveCommand] is what the voice assistant sends. It ends in
/// `audioController.play(kLiveIndex)`, like the quick action in `shortcutPlay`.
const kPlayLiveCommand = 'play_live_kirtan';

/// Opens the Hukamnama reader. See [openHukamnamaReader].
const kOpenHukamnamaCommand = 'open_hukamnama';

/// Opens the Hukamnama reader on top of whatever is showing, unless it is
/// already the screen on top. Tapping the widget twice must not stack two.
///
/// [navigator] is null while the app has no navigator yet, which is the first
/// moments of a cold start. This throws a [PlatformException] then. The native
/// side retries a command that fails, so the tap is not lost.
void openHukamnamaReader(
  NavigatorState? navigator, {
  Route<void> Function() route = HukamnamaScreen.route,
}) {
  if (navigator == null) {
    throw PlatformException(
      code: 'not_ready',
      message: 'The app has no navigator yet.',
    );
  }
  var alreadyOpen = false;
  // A predicate that stops at once pops nothing. It only reads the top route.
  navigator.popUntil((top) {
    alreadyOpen = top.settings.name == HukamnamaScreen.routeName;
    return true;
  });
  if (!alreadyOpen) navigator.push(route());
}
