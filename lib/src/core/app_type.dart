import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/palette.dart';

/// The type scale.
///
/// Two voices. Titles are set in Noto Serif, with Noto Serif Gurmukhi behind
/// it, so "Live Kirtan" and "ਲਾਈਵ ਕੀਰਤਨ" come from the same family and the
/// app keeps one voice in either language. Everything you read or tap is set
/// in Manrope with Noto Sans Gurmukhi behind it.
///
/// Tracking changes with size: large serif titles are pulled in, small labels
/// are let out. One letter-spacing for every size is wrong somewhere.
///
/// Gurmukhi sits taller than Latin and its vowel signs hang above the line, so
/// any style that can carry Gurmukhi gets at least 1.3 line height.
abstract final class AppType {
  /// Whether titles and labels get their size-specific letter spacing.
  ///
  /// Letter spacing breaks Gurmukhi: it pushes vowel signs such as ੁ and ੂ off
  /// the letters they belong to, so "ਗੁਰੂ" falls apart. Tracking therefore
  /// applies only while the app is in English. The app shell sets this when
  /// the language changes, before the tree rebuilds.
  static bool tracking = true;

  static double _track(double value) => tracking ? value : 0;

  static TextStyle get largeTitle =>
      _largeTitle.copyWith(letterSpacing: _track(-0.6));
  static TextStyle get title => _title.copyWith(letterSpacing: _track(-0.4));
  static TextStyle get title2 =>
      _title2.copyWith(letterSpacing: _track(-0.2));
  static TextStyle get eyebrow => _eyebrow.copyWith(letterSpacing: _track(1.2));

  static const sans = 'Manrope';
  static const sansFallback = ['NotoSansGurmukhi'];
  static const serif = 'NotoSerif';
  static const serifFallback = ['NotoSerifGurmukhi'];

  /// Gurbani itself. Serif Gurmukhi first, because that is the face the words
  /// are printed in.
  static const gurbaniFamily = 'NotoSerifGurmukhi';

  static const _largeTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w600,
    color: Palette.foreground,
  );

  static const _title = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 28,
    height: 1.18,
    fontWeight: FontWeight.w600,
    color: Palette.foreground,
  );

  static const _title2 = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 21,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: Palette.foreground,
  );

  static const headline = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: Palette.foreground,
  );

  static const body = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 17,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: Palette.foreground,
  );

  static const callout = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: Palette.muted,
  );

  static const footnote = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: Palette.muted,
  );

  /// Small caps-style labels: "LIVE", section eyebrows. Let out, not pulled in.
  static const _eyebrow = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: Palette.gold,
  );

  static const gurbani = TextStyle(
    fontFamily: gurbaniFamily,
    fontSize: 22,
    height: 1.6,
    fontWeight: FontWeight.w600,
    color: Palette.foreground,
  );

  /// Tabular figures, so a ticking clock does not shuffle sideways.
  static const timecode = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
    color: Palette.muted,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
