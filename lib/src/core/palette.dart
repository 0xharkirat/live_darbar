import 'package:flutter/material.dart';

/// The one palette. Dark only, by decision.
///
/// The app is listened to at Amritvela, at night, and in the car, so the
/// canvas is a warm near-black and the only strong colour is gold. Gold is the
/// colour of the Darbar Sahib itself, which is the subject of every painting in
/// the app; the orange this replaced was a stock UI orange with no reason to
/// be here.
///
/// Every ratio below is WCAG contrast against the surface the colour sits on,
/// measured, not guessed. The audience skews older, so body text clears AA
/// (4.5:1) everywhere, most of it by a wide margin.
abstract final class Palette {
  /// The canvas. 17.6:1 under [foreground].
  static const background = Color(0xFF0C0A09);

  /// Grouped content one step above the canvas.
  ///
  /// Dark surfaces get lighter as they come forward. They do not gain shadow.
  static const surface = Color(0xFF171310);

  /// Pressed, selected, and the floating player.
  static const surfaceHigh = Color(0xFF231D18);

  /// Hairlines. Solid rather than alpha, because an alpha white edge glows on
  /// a dark canvas and reads as a light source instead of an edge.
  static const border = Color(0xFF3A322B);

  /// Primary text. 17.6:1 on [background], 16.4:1 on [surface].
  static const foreground = Color(0xFFF5F1EB);

  /// Secondary text. 8.0:1 on [background], 7.5:1 on [surface].
  static const muted = Color(0xFFADA398);

  /// Tertiary marks only: dividers in text, disabled icons. 3.5:1, so never
  /// for body text.
  static const faint = Color(0xFF6E655C);

  /// The accent. 10.1:1 on [background], 9.5:1 on [surface].
  static const gold = Color(0xFFE8B04B);

  /// Text and icons on [gold]. 10.1:1.
  static const onGold = Color(0xFF0C0A09);

  /// The live signal. Apple's dark-mode system red, because a red dot already
  /// means "on air" to everyone. 5.8:1 on [background].
  static const live = Color(0xFFFF453A);

  /// Errors. 5.8:1 on [background]. The same red as [live] on purpose: there
  /// is one red in this app, and it always means the stream.
  static const danger = live;
}
