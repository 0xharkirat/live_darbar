import 'package:flutter/services.dart';

/// Loads the app's real fonts, so a test lays text out the way a phone does.
///
/// Without them `flutter test` draws every glyph as a square of the Ahem font,
/// which is about 1.7 times as wide as Geist. A layout test that must answer
/// "does it fit on a phone?" needs the real widths.
Future<void> loadAppFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await family('Geist', [
    'assets/fonts/Geist-400.ttf',
    'assets/fonts/Geist-500.ttf',
    'assets/fonts/Geist-700.ttf',
  ]);
  await family('NotoSansGurmukhi', [
    'assets/fonts/NotoSansGurmukhi-400.ttf',
    'assets/fonts/NotoSansGurmukhi-500.ttf',
    'assets/fonts/NotoSansGurmukhi-700.ttf',
  ]);
  await family('GeistSerif', ['assets/fonts/GeistSerif-400.ttf']);
  await family('TiroGurmukhi', ['assets/fonts/TiroGurmukhi-400.ttf']);
  await family('packages/cupertino_icons/CupertinoIcons', [
    'packages/cupertino_icons/assets/CupertinoIcons.ttf',
  ]);
}
