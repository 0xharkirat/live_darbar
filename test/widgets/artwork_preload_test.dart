import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/views/widgets/artwork.dart';

import '../support/app_harness.dart';

/// The 3 paintings of Home are decoded before the first frame, while the
/// native splash is up, so Home appears whole and not painting by painting.
void main() {
  setUp(() => PaintingBinding.instance.imageCache.clear());

  /// The images Home draws at their own size: the hero and the 2 tiles. (The
  /// mini player draws a 48 point copy, which is resized, and is hidden until
  /// sound plays.)
  List<Element> homePaintings(WidgetTester tester) => find
      .byType(Image)
      .evaluate()
      .where((e) => (e.widget as Image).image is AssetImage)
      .toList();

  /// Whether the painting has a decoded picture to draw this frame.
  bool decoded(WidgetTester tester, Element painting) => tester
      .widget<RawImage>(
        find.descendant(
          of: find.byWidget(painting.widget),
          matching: find.byType(RawImage),
        ),
      )
      .image !=
      null;

  testWidgets('without the preload, Home draws no painting at first', (
    tester,
  ) async {
    await pumpApp(tester);

    final paintings = homePaintings(tester);
    expect(paintings, hasLength(3));
    expect(paintings.where((p) => decoded(tester, p)), isEmpty);
  });

  testWidgets('after the preload, Home draws all 3 in its first frame', (
    tester,
  ) async {
    await tester.runAsync(preloadArtwork);

    await pumpApp(tester);

    final paintings = homePaintings(tester);
    expect(paintings, hasLength(3));
    expect(paintings.where((p) => decoded(tester, p)), hasLength(3));
  });

  testWidgets('the preload names the 3 paintings of the app', (tester) async {
    await tester.runAsync(preloadArtwork);

    final cache = PaintingBinding.instance.imageCache;
    expect(cache.currentSize, 3);
  });

  testWidgets('a painting that cannot load does not stop the preload', (
    tester,
  ) async {
    await tester.runAsync(
      () => preloadArtwork(
        extra: [AssetImage('assets/images/not_there.jpg')],
      ),
    );

    expect(PaintingBinding.instance.imageCache.currentSize, 3);
  });
}
