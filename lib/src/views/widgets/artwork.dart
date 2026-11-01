import 'package:flutter/material.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';

/// The painting that belongs to each source.
///
/// These are Kanwar Singh's paintings, and they are most of the app's
/// character. They are only 750 px wide, so they are never shown wider than a
/// card; full-bleed on a 3x phone would show the softness.
String artworkFor(int index) => switch (index) {
      kMukhwakIndex => 'assets/images/1.jpg',
      kKathaIndex => 'assets/images/2.jpg',
      _ => 'assets/images/0.jpg',
    };

/// A painting clipped to the app's continuous corner shape.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.index,
    this.radius = 20,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  });

  final int index;
  final double radius;
  final double? width;
  final double? height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        artworkFor(index),
        width: width,
        height: height,
        fit: BoxFit.cover,
        alignment: alignment,
        // Decoded at the size it is drawn, not at full resolution, which
        // keeps three paintings in memory cheap on low-end phones.
        cacheWidth: width == null
            ? null
            : (width! * MediaQuery.devicePixelRatioOf(context)).round(),
        gaplessPlayback: true,
      ),
    );
  }
}
