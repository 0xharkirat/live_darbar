import 'package:live_darbar/src/home_screen_widget/widget_playback.dart';

/// The links the iPhone widget opens, and what each tap does.
///
/// An Android widget sends its taps to the media session with no screen (see
/// WidgetControlReceiver.kt). An iPhone widget cannot: a Flutter app started
/// in the background has no engine to play with. So each part of the iPhone
/// widget is a link that opens the app, and the app does what the button
/// showed. Siri's intents work the same way (`openAppWhenRun`).
///
/// The links are fixed, and the app reads nothing from them but which one it
/// is. Any app or web page can open a custom scheme, so the worst a forged
/// link can do is what the widget can do: play or stop kirtan, or open the
/// reader.
///
/// Each link carries `homeWidget`, the query item that `home_widget` looks
/// for before it hands a link to Dart. LiveDarbarWidget.swift writes the same
/// strings.
const kWidgetLinkScheme = 'livedarbar';

/// A part of the iPhone widget that opens the app.
enum WidgetLink {
  /// The Live Kirtan button.
  live,

  /// The Hukamnama button.
  hukamnama,

  /// The widget away from its buttons. It opens the Hukamnama reader.
  open,
}

/// The link [uri] names, or null when it is not one of the widget's.
WidgetLink? widgetLinkFrom(Uri? uri) {
  if (uri == null || uri.scheme != kWidgetLinkScheme) return null;
  if (uri.host != 'widget' || uri.pathSegments.length != 1) return null;
  return switch (uri.pathSegments.single) {
    'live' => WidgetLink.live,
    'hukamnama' => WidgetLink.hukamnama,
    'open' => WidgetLink.open,
    _ => null,
  };
}

/// What the app does for a tap on the widget.
enum WidgetTap { playLive, stop, playHukamnama, pause, openReader }

/// What a tap on [link] does, from what the player does [now].
///
/// The app decides from the player, not from the picture on the widget. The
/// picture can be a moment old, and a tap must never stop a source that the
/// listener sees as stopped. These are the Android widget's rules: Live Kirtan
/// plays or stops, and the Hukamnama plays or pauses. A source that is still
/// opening counts as on, so a second tap cancels it.
WidgetTap widgetTapFor(WidgetLink link, WidgetPlayback now) {
  final on = now.state == WidgetPlayState.playing ||
      now.state == WidgetPlayState.loading;
  return switch (link) {
    WidgetLink.open => WidgetTap.openReader,
    WidgetLink.live =>
      on && now.source == WidgetSource.live ? WidgetTap.stop : WidgetTap.playLive,
    WidgetLink.hukamnama => on && now.source == WidgetSource.hukamnama
        ? WidgetTap.pause
        : WidgetTap.playHukamnama,
  };
}
