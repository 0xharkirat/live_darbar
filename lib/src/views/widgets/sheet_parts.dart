import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// The padding inside a sheet's scroll view: [horizontal] at the sides, 10 at
/// the top, and 16 at the bottom plus the system navigation bar.
///
/// The space is inside the scroll view, not a `SafeArea` around it. A
/// `SafeArea` shrinks the scrolling area, so a line is cut off as it reaches
/// the bar. Here it slides under the bar, and the last line stops above it,
/// whatever the phone's bar is. It reads the view padding, which is the bar
/// itself and does not change while a keyboard is up.
EdgeInsets sheetPadding(BuildContext context, {double horizontal = 24}) {
  final sides = MediaQuery.paddingOf(context);
  final bar = MediaQuery.viewPaddingOf(context).bottom;
  return EdgeInsets.fromLTRB(
    horizontal + sides.left,
    10,
    horizontal + sides.right,
    16 + bar,
  );
}

/// The sheet's surface, grabber and padding, as the update sheet draws them.
/// Every small sheet that asks the listener 1 thing (the reminder, the widget
/// steps) builds on it.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecoration(
        color: Palette.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: Palette.border),
        ),
      ),
      // Scrolls when it does not fit, on a small phone or at a large text
      // size.
      child: SingleChildScrollView(
        // Hands a swipe down at the top of the list to the sheet.
        controller: appSheetScrollController(context),
        child: Padding(
          padding: sheetPadding(context),
          child: AnimatedSize(
            duration: Motion.quick,
            curve: Motion.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Palette.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 1 gold button of the sheet.
class GoldSheetButton extends StatelessWidget {
  const GoldSheetButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onTap;

  /// 54 on a sheet. A card takes a shorter one, 44, which is still a target.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: Palette.gold,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: AppType.headline.copyWith(color: Palette.onGold),
          ),
        ),
      ),
    );
  }
}

/// The quiet way out: words only, with a target of 48 points.
class QuietSheetButton extends StatelessWidget {
  const QuietSheetButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppType.callout.copyWith(color: Palette.muted),
          ),
        ),
      ),
    );
  }
}
