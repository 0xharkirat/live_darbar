import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/palette.dart';

/// The type scale.
///
/// Two voices. Titles are set in Geist Serif, the face darbar.live uses, with
/// Tiro Gurmukhi behind it, so "Live Kirtan" and "ਲਾਈਵ ਕੀਰਤਨ" are both
/// serif and the app keeps one voice in either language. Everything you read
/// or tap is set in Geist, the sans of the same family, with Noto Sans
/// Gurmukhi behind it.
///
/// Geist Serif and Tiro Gurmukhi each have 1 weight, 400. A title that asked
/// either for 600 would get a synthesized bold, which adds about 15% ink and
/// smears the strokes. So titles and Gurbani are 400 in both languages.
///
/// Tracking changes with size: large serif titles are pulled in, small labels
/// are let out. One letter-spacing for every size is wrong somewhere.
///
/// Gurmukhi sits taller than Latin and its vowel signs hang above the line, so
/// any style that can carry Gurmukhi gets at least 1.3 line height. The styles
/// whose Latin height is below that take a taller one in Punjabi (see [_lh]).
abstract final class AppType {
  /// Whether titles and labels get their size-specific letter spacing.
  ///
  /// Letter spacing breaks Gurmukhi: it pushes vowel signs such as ੁ and ੂ off
  /// the letters they belong to, so "ਗੁਰੂ" falls apart. Tracking therefore
  /// applies only while the app is in English. The app shell sets this when
  /// the language changes, before the tree rebuilds.
  static bool tracking = true;

  static double _track(double value) => tracking ? value : 0;

  /// A line height for Latin text, and a taller one for Gurmukhi, whose vowel
  /// signs hang above and below the line. [tracking] doubles as "is English".
  static double _lh(double latin, double gurmukhi) =>
      tracking ? latin : gurmukhi;

  // Both title faces have 1 weight (Geist Serif, Tiro Gurmukhi), so titles
  // are 400 in either language and nothing is synthesized.
  static TextStyle get largeTitle => _largeTitle.copyWith(
        letterSpacing: _track(-0.6),
        height: _lh(1.15, 1.3),
      );
  static TextStyle get title => _title.copyWith(
        letterSpacing: _track(-0.4),
        height: _lh(1.18, 1.3),
      );
  static TextStyle get title2 => _title2.copyWith(
        letterSpacing: _track(-0.2),
        height: _lh(1.25, 1.35),
      );
  // 0.06em at 12 px, not 0.1em: Geist capitals are already wide.
  static TextStyle get eyebrow =>
      _eyebrow.copyWith(letterSpacing: _track(0.72));
  static TextStyle get body => _body.copyWith(height: _lh(1.5, 1.6));
  static TextStyle get callout => _callout.copyWith(height: _lh(1.4, 1.5));
  static TextStyle get footnote => _footnote.copyWith(height: _lh(1.4, 1.5));

  static const sans = 'Geist';
  static const sansFallback = ['NotoSansGurmukhi'];
  static const serif = 'GeistSerif';
  static const serifFallback = ['TiroGurmukhi'];

  /// Gurbani itself. Serif Gurmukhi first, because that is the face the words
  /// are printed in. Tiro Gurmukhi has 1 weight, so [gurbani] stays at 400.
  static const gurbaniFamily = 'TiroGurmukhi';

  static const _largeTitle = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w400,
    color: Palette.foreground,
  );

  static const _title = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 28,
    height: 1.18,
    fontWeight: FontWeight.w400,
    color: Palette.foreground,
  );

  static const _title2 = TextStyle(
    fontFamily: serif,
    fontFamilyFallback: serifFallback,
    fontSize: 21,
    height: 1.25,
    fontWeight: FontWeight.w400,
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

  static const _body = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 17,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: Palette.foreground,
  );

  static const _callout = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: Palette.muted,
  );

  static const _footnote = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 13,
    height: 1.4,
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
    fontWeight: FontWeight.w400,
    color: Palette.foreground,
  );

  /// Tabular figures, so a ticking clock does not shuffle sideways. It also
  /// sets the live rail's label, "ਲਾਈਵ" in Punjabi, so it falls back to Noto
  /// Sans Gurmukhi like every other label rather than to a system face.
  static const timecode = TextStyle(
    fontFamily: sans,
    fontFamilyFallback: sansFallback,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
    color: Palette.muted,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
