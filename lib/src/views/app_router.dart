import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/widgets/fade_page_route.dart';

/// The app's pages, by name.
///
/// A page is pushed by name (`Navigator.pushNamed`) so that the web has
/// something to show in the address bar. The web reads a route's name from
/// the navigator and writes it after the `#`: `/app/#/hukamnama`. A reload,
/// a bookmark or a shared link then opens that page, and the browser's back
/// button pops it: the web puts the navigator in single-entry history mode,
/// where back calls the navigator's own pop. That pops a sheet as well as a
/// page, which a history entry per page would not.
///
/// The address stays after the `#`, not in the path, on purpose. The app is
/// served from `/app/` by a static host with no rewrite rule, so a path such
/// as `/app/hukamnama` would answer 404 on reload, and `/app/` must keep
/// loading home.
///
/// Home is not here. It is `MaterialApp.home`, named `/`. Opening
/// `/app/#/hukamnama` builds home first and the page over it, so back has
/// somewhere to go.
abstract final class AppRoutes {
  static const home = '/';
  static const hukamnama = '/hukamnama';
  static const about = '/about';

  /// Builds the route for a pushed page, or null for a name it does not know.
  ///
  /// The web fades pages ([FadePageRoute]). iOS and Android slide them, with
  /// the swipe back. [web] is for tests; the app passes nothing.
  static RouteFactory generator({bool? web}) {
    final fade = web ?? (kIsWeb || kIsWasm);
    return (settings) {
      final WidgetBuilder? builder = switch (settings.name) {
        hukamnama => (_) => const HukamnamaScreen(),
        about => (_) => const AboutScreen(),
        _ => null,
      };
      if (builder == null) return null;
      return fade
          ? FadePageRoute<void>(settings: settings, builder: builder)
          : CupertinoPageRoute<void>(settings: settings, builder: builder);
    };
  }
}
