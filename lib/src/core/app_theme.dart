import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// One theme, built from [Palette].
///
/// This used to expose seven selectable accent schemes through an
/// `AppThemeColor` enum and a picker. All of it is gone: the app is dark only
/// and one designed palette, which is a decision rather than a default.
///
/// Fonts are bundled assets rather than fetched by `google_fonts` at runtime.
/// That was costing a network round trip on first launch, a visible swap from
/// the fallback face, and on an offline first launch the intended face never
/// arrived at all. Manrope carries no Gurmukhi, so Punjabi silently fell back
/// to whatever the OS supplied and the app rendered in two unrelated
/// typefaces. Noto Sans Gurmukhi is declared as a fallback on the same family,
/// so each script gets a face that was chosen for it.
abstract final class AppTheme {
  static const fontFamily = 'Manrope';
  static const fontFamilyFallback = ['NotoSansGurmukhi'];

  static ShadColorScheme get colorScheme => const ShadColorScheme(
        background: Palette.background,
        foreground: Palette.foreground,
        card: Palette.surface,
        cardForeground: Palette.foreground,
        popover: Palette.surface,
        popoverForeground: Palette.foreground,
        primary: Palette.primary,
        primaryForeground: Palette.onPrimary,
        secondary: Palette.surfaceHigh,
        secondaryForeground: Palette.foreground,
        muted: Palette.surfaceHigh,
        mutedForeground: Palette.muted,
        accent: Palette.surfaceHigh,
        accentForeground: Palette.foreground,
        destructive: Palette.danger,
        destructiveForeground: Palette.onPrimary,
        border: Palette.border,
        input: Palette.border,
        ring: Palette.primary,
        selection: Palette.surfaceHigh,
      );

  static ShadThemeData get shad => ShadThemeData(
        colorScheme: colorScheme,
        brightness: Brightness.dark,
        textTheme: ShadTextTheme(
          family: fontFamily,
          package: null,
        ).apply(
          bodyColor: Palette.foreground,
          displayColor: Palette.foreground,
          fontFamilyFallback: fontFamilyFallback,
        ),
      );

  static ThemeData get material => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.background,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        colorScheme: const ColorScheme.dark(
          surface: Palette.background,
          onSurface: Palette.foreground,
          primary: Palette.primary,
          onPrimary: Palette.onPrimary,
          secondary: Palette.surfaceHigh,
          onSecondary: Palette.foreground,
          error: Palette.danger,
          onError: Palette.onPrimary,
          outline: Palette.border,
        ),
      );
}
