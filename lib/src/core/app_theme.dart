import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';

/// One theme, built from [Palette] and [AppType]. Dark only.
///
/// The app draws its own components, so this theme only has to make the few
/// stock widgets it still uses (scaffolds, sheets, progress indicators, text
/// selection) agree with them. There is no UI kit underneath any more: the
/// previous one shipped six icon fonts and a component look that belonged to
/// the web, not to a phone in someone's hand.
abstract final class AppTheme {
  static ThemeData get material {
    const scheme = ColorScheme.dark(
      surface: Palette.background,
      onSurface: Palette.foreground,
      surfaceContainerHighest: Palette.surfaceHigh,
      primary: Palette.gold,
      onPrimary: Palette.onGold,
      secondary: Palette.surfaceHigh,
      onSecondary: Palette.foreground,
      error: Palette.danger,
      onError: Palette.onGold,
      outline: Palette.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.background,
      canvasColor: Palette.background,
      fontFamily: AppType.sans,
      fontFamilyFallback: AppType.sansFallback,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      // iOS-style horizontal page transitions everywhere, with the edge swipe
      // back, because the back gesture is the one people already know.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Palette.gold,
        selectionColor: Color(0x55E8B04B),
        selectionHandleColor: Palette.gold,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Palette.gold,
        linearTrackColor: Palette.border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Palette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Palette.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppType.headline,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Color(0x99000000),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Palette.gold,
      ),
    );
  }
}
