import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';

/// Makes a part of a screen that failed to build a small, calm box.
///
/// Flutter draws a grey box for a widget that throws while it builds, in a
/// release build, and a red screen with the message in a debug build. The grey
/// box says nothing: the listener cannot tell a slow app from a broken one.
/// So a release build gets [ErrorView]. A debug build is left alone, because a
/// developer needs the message and the stack.
///
/// Call it once, before the app starts. [debug] is for a test; the default is
/// the build the app runs in.
void installErrorView({bool debug = kDebugMode}) {
  if (debug) return;
  ErrorWidget.builder = (details) => const ErrorView();
}

/// What stands where a widget failed to build.
///
/// It names no exception and shows no stack: the listener has done nothing
/// wrong, and nothing in the box helps them. It is small, so the rest of the
/// screen stays. It has no alarm colour, no icon and no button.
///
/// It must work wherever the widget that failed stood, so it needs nothing
/// from above it: no theme, no localization, no text direction, no size. The
/// words come in both languages together, like the start-up failure screen,
/// because the part that failed may be the language setting. In a tight space
/// it shrinks and does not overflow.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    // Looked up by name, not from the context: the widget above may be the
    // one that sets up localization.
    final en = lookupAppLocalizations(const Locale('en'));
    final pa = lookupAppLocalizations(const Locale('pa'));

    TextStyle style(TextStyle base) => base.copyWith(
          color: Palette.muted,
          decoration: TextDecoration.none,
        );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Palette.surface,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Palette.border),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(en.error_view_title, style: style(AppType.footnote)),
                  const SizedBox(height: 2),
                  // Gurmukhi takes no letter spacing and a taller line.
                  Text(
                    pa.error_view_title,
                    style: style(AppType.footnote)
                        .copyWith(letterSpacing: 0, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
