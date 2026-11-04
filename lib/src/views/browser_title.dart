import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/platform.dart';
import 'package:live_darbar/src/views/app_router.dart';

/// Which page is on top, by the name it was pushed with.
///
/// It is the navigator's own observer, so it sees every push and pop, in the
/// order they happen, and the page that comes back to the top after a pop. A
/// sheet or a dialog is not a page, and does not change the answer: the title
/// of the tab stays the page under it.
class PageNames extends NavigatorObserver {
  /// The name of the page on top: `/`, `/hukamnama`, `/about`, `/history`.
  final ValueNotifier<String?> top = ValueNotifier<String?>(null);

  void _show(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    // Later, not now. The first route is pushed while the app is building,
    // and a listener must not be told to rebuild in the middle of that.
    SchedulerBinding.instance.addPostFrameCallback((_) => top.value = name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _show(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _show(newRoute);

  void dispose() => top.dispose();
}

/// The one [PageNames] of the app. Give it to `MaterialApp.navigatorObservers`.
final pageNamesProvider = Provider<PageNames>((ref) {
  final names = PageNames();
  ref.onDispose(names.dispose);
  return names;
});

/// The words in a browser tab for the page [route], in the app's language.
///
/// Page first and app last, because a tab cuts the end of a long title when
/// several are open. Home is the app's name alone.
String browserTitleFor(String? route, AppLocalizations l10n) {
  final app = l10n.app_title;
  return switch (route) {
    AppRoutes.hukamnama => '${l10n.mukhwak} · $app',
    AppRoutes.about => '${l10n.about_this_app} · $app',
    AppRoutes.history => '${l10n.history_screen_title} · $app',
    _ => app,
  };
}

/// Sets the browser tab's title to the page on top, on the web.
///
/// With 1 title for every page, a listener with several tabs open cannot tell
/// them apart, and a bookmark or the history says nothing. A [Title] on each
/// page would not do: a page under another is not rebuilt when the top page
/// closes, so the tab would keep the closed page's name. This sits above the
/// navigator and follows [PageNames], so each pop puts the right title back.
///
/// On a phone it does nothing: there is no tab, and [Title] would rename the
/// app in the Android task list.
class BrowserTitle extends ConsumerWidget {
  const BrowserTitle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isWebProvider)) return child;
    final names = ref.watch(pageNamesProvider);
    return ValueListenableBuilder<String?>(
      valueListenable: names.top,
      child: child,
      builder: (context, route, child) => Title(
        title: browserTitleFor(route, AppLocalizations.of(context)!),
        color: Palette.background,
        child: child!,
      ),
    );
  }
}
