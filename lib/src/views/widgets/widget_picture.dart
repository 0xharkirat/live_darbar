import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/palette.dart';

/// A picture of the home screen widget, idle, in the app's language.
///
/// It is the real SwiftUI view of the iPhone widget, drawn on a Mac by
/// `tool/widget_render/run.sh`, not a copy drawn by hand. The Android widget
/// has the same 2 lines and 2 buttons, so 1 picture serves both phones.
///
/// The picture shows what the listener will get, so it hides from a screen
/// reader. The words next to it say it.
class WidgetPicture extends StatelessWidget {
  const WidgetPicture({super.key, required this.width});

  final double width;

  /// The size of the picture, a medium widget: 338 x 158 points.
  static const aspect = 338 / 158;

  /// The widget's corner, 22 of its 338 points, scaled to [width].
  static const _cornerRatio = 22 / 338;

  @override
  Widget build(BuildContext context) {
    final punjabi = Localizations.localeOf(context).languageCode == 'pa';
    final radius = BorderRadius.circular(width * _cornerRatio);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width / aspect,
        child: DecoratedBox(
          // A hairline, because the widget is darker than the surface it
          // sits on, and its edge would be lost.
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: radius,
              side: const BorderSide(color: Palette.border),
            ),
          ),
          child: ClipRSuperellipse(
            borderRadius: radius,
            child: Image.asset(
              punjabi
                  ? 'assets/images/widget_idle_pa.png'
                  : 'assets/images/widget_idle_en.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
