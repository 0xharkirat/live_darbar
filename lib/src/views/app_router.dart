import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/screens/history_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/widgets/fade_page_route.dart';

/// The app's pages, by name.
///
/// A page is pushed by name (`Navigator.pushNamed`) so that the web has
/// something to show in the address bar. The web reads a route's name from
/// the navigator and writes it into the path, after the base href:
/// `/app/hukamnama` (main.dart calls `usePathUrlStrategy`). A reload, a
/// bookmark or a shared link then opens that page, and the browser's back
/// button pops it: the web puts the navigator in single-entry history mode,
/// where back calls the navigator's own pop. That pops a sheet as well as a
/// page, which a history entry per page would not.
///
/// Firebase answers every `/app/` path with the app (`firebase.json`), so a
/// reload of `/app/hukamnama` loads the app and not a 404. Until 7 November
/// 2026 the page went after a `#`, `/app/#/hukamnama`. web/index.html moves
/// such an old link into the path before Flutter starts.
///
/// The reader of an earlier day has its own address,
/// `/app/hukamnama/2026-11-01` ([hukamnamaOn]). A day that is not a day, or
/// that is not before today, opens today's reader (see [HukamnamaScreen.day]),
/// so an old or mistyped link never ends on an error page.
///
/// Home is not here. It is `MaterialApp.home`, named `/`. Opening
/// `/app/hukamnama` builds home first and the page over it, so back has
/// somewhere to go.
abstract final class AppRoutes {
  static const home = '/';
  static const hukamnama = '/hukamnama';
  static const about = '/about';
  static const history = '/history';
  static const sangrand = '/sangrand';

  /// The address of the reader for [day]: `/hukamnama/2026-11-01`.
  static String hukamnamaOn(DateTime day) => '$hukamnama/${sgpcDayIso(day)}';

  /// The day that [name] addresses, as UTC midnight, or null when it names no
  /// day: the plain `/hukamnama`, another page, or a day that does not exist.
  static DateTime? hukamnamaDayOf(String? name) {
    final match =
        RegExp(r'^/hukamnama/(\d{4}-\d{2}-\d{2})$').firstMatch(name ?? '');
    if (match == null) return null;
    try {
      return parseSgpcDay(match.group(1)!);
    } on FormatException {
      return null;
    }
  }

  /// Whether [name] is the reader of today or of an earlier day.
  static bool isHukamnama(String? name) =>
      name == hukamnama || (name?.startsWith('$hukamnama/') ?? false);

  /// Builds the route for a pushed page, or null for a name it does not know.
  ///
  /// The web fades pages ([FadePageRoute]). iOS and Android slide them, with
  /// the swipe back. [web] is for tests; the app passes nothing.
  static RouteFactory generator({bool? web}) {
    final fade = web ?? (kIsWeb || kIsWasm);
    return (settings) {
      final name = settings.name;
      final WidgetBuilder? builder = switch (name) {
        // Any address under /hukamnama/ is the reader. A bad day reads as no
        // day, and the reader then shows today's.
        _ when isHukamnama(name) => (_) =>
            HukamnamaScreen(day: hukamnamaDayOf(name)),
        about => (_) => const AboutScreen(),
        history => (_) => const HistoryScreen(),
        sangrand => (_) => const SangrandScreen(),
        _ => null,
      };
      if (builder == null) return null;
      return fade
          ? FadePageRoute<void>(settings: settings, builder: builder)
          : CupertinoPageRoute<void>(settings: settings, builder: builder);
    };
  }
}
