import 'package:flutter/material.dart';

/// The one palette. Dark only, by decision, not by default.
///
/// There used to be seven selectable accent colours behind a picker. They came
/// out because a colour picker is a setting nobody asked for that doubles the
/// surface every future change has to be checked against, and because none of
/// the seven were designed against this app's warm base.
///
/// Every value below was measured rather than chosen by eye. Ratios are WCAG,
/// against the surface each colour actually sits on, and are quoted per token
/// so a future change can be checked rather than guessed at. The audience
/// skews older, so body text is held to AA (4.5:1) and most pairs clear it
/// with room to spare.
///
/// Neutrals carry a deliberate warm bias. Pure greys would fight the amber and
/// read as cold under it; these agree with it. None of them is `#808080`,
/// which always reads as placeholder.
abstract final class Palette {
  /// The canvas. Harkirat's chosen base, already warm at R12 G10 B9.
  static const background = Color(0xFF0C0A09);

  /// Cards and rows, one step above the canvas.
  ///
  /// Dark mode is not inverted light mode: surfaces get *lighter* as they come
  /// forward, they do not gain shadow.
  static const surface = Color(0xFF1C1917);

  /// Pressed and selected states.
  static const surfaceHigh = Color(0xFF292524);

  /// Solid, deliberately, not `white.withValues(alpha: ...)`.
  ///
  /// Alpha borders glow on a dark background; a solid tone of the same warmth
  /// sits quietly and reads as an edge rather than a light source.
  static const border = Color(0xFF3F3A36);

  /// Primary text. 18.78:1 on [background], 16.62:1 on [surface].
  static const foreground = Color(0xFFFAF9F7);

  /// Secondary text. 7.83:1 on [background], 6.93:1 on [surface].
  ///
  /// Comfortably past AA rather than scraping it, because "secondary" should
  /// mean quieter, not harder to read, and this audience is not young.
  static const muted = Color(0xFFA8A29E);

  /// The accent. 7.05:1 on [background], 6.24:1 on [surface].
  ///
  /// Amber rather than a saturated brand colour: it belongs to the same family
  /// as the Golden Temple artwork the app is built around, and at this
  /// lightness it clears AA for body text, not merely for large text.
  static const primary = Color(0xFFF97316);

  /// Text and icons on top of [primary]. 7.05:1 against it.
  static const onPrimary = Color(0xFF0C0A09);

  /// Errors. 7.14:1 on [background].
  ///
  /// Desaturated from a full red, which vibrates against a dark background.
  static const danger = Color(0xFFF87171);

  /// Disabled content.
  ///
  /// A dedicated token rather than `opacity: 0.4`, because opacity-based
  /// disabling passes contrast on some surfaces and fails on others, while a
  /// token behaves the same everywhere.
  static const disabled = Color(0xFF57534E);
}
