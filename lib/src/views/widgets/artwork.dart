import 'dart:async';

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

/// Decodes the paintings that Home draws, so they are ready for its first
/// frame.
///
/// Flutter loads an image when a widget first asks for it, and decoding takes
/// a few frames. Home would then show its 3 paintings one by one, over the
/// splash it just replaced. Called before `runApp`, while the native splash is
/// still up, this puts each painting in the image cache, and the `Image`
/// widgets find it there.
///
/// It does what `precacheImage` does, without a [BuildContext], because none
/// exists before the first frame. A painting that cannot load is skipped: the
/// widget that wants it reports the error where it can be seen. It gives up
/// after [timeout], so a slow web connection never holds the app back.
Future<void> preloadArtwork({
  Duration timeout = const Duration(seconds: 3),
  List<ImageProvider> extra = const [],
}) {
  final providers = [
    for (final index in const [kLiveIndex, kMukhwakIndex, kKathaIndex])
      AssetImage(artworkFor(index)),
    ...extra,
  ];
  return Future.wait(providers.map(_decode)).then((_) {}).timeout(
        timeout,
        onTimeout: () {},
      );
}

Future<void> _decode(ImageProvider provider) {
  final done = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  void finish() {
    stream.removeListener(listener);
    if (!done.isCompleted) done.complete();
  }

  listener = ImageStreamListener(
    (image, synchronousCall) => finish(),
    onError: (error, stack) => finish(),
  );
  stream.addListener(listener);
  return done.future;
}

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
