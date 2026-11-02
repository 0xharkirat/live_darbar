import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/platform.dart';

/// The navigation bar of a pushed page: a large title that shrinks into the
/// bar as the page scrolls, and a way back.
///
/// On a phone the back control is Cupertino's own, at the screen's left edge,
/// where a thumb and the edge swipe both expect it.
///
/// On the web the page is a column [contentWidth] wide in the middle of a
/// window that can be 2000 points across. The same control at the window's
/// left edge sits a long way from the words it belongs to, and reads as no
/// back button at all. So on the web the bar lines up with the column: the
/// back control, the title and [trailing] all sit at the column's edges, and
/// the back control always carries the word it goes back to.
class AppNavBar extends ConsumerWidget {
  const AppNavBar({
    super.key,
    required this.title,
    required this.contentWidth,
    this.trailing,
  });

  final String title;

  /// The width of the page's column, which the web lines the bar up with.
  final double contentWidth;

  final Widget? trailing;

  /// The page's own 20 point margin, where the column begins on a phone.
  static const _margin = 20.0;

  /// The chevron sits this far in from the start of a leading widget.
  static const _chevronInset = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final onWeb = ref.watch(isWebProvider);

    // Where the column's edge is: the margin, or further in when the window
    // is wider than the column.
    final edge = math.max(
      _margin,
      (MediaQuery.sizeOf(context).width - contentWidth) / 2,
    );

    return CupertinoSliverNavigationBar(
      largeTitle: Text(title, style: AppType.largeTitle),
      middle: Text(title, style: AppType.headline),
      alwaysShowMiddle: false,
      previousPageTitle: l10n.app_title,
      backgroundColor: Palette.background.withValues(alpha: 0.92),
      border: null,
      trailing: trailing,
      padding: onWeb
          ? EdgeInsetsDirectional.only(start: edge, end: edge - 8)
          : null,
      leading: onWeb && Navigator.canPop(context)
          ? Transform.translate(
              offset: const Offset(-_chevronInset, 0),
              child: CupertinoNavigationBarBackButton(
                previousPageTitle: l10n.app_title,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
    );
  }
}
