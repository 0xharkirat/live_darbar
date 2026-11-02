@Tags(['screens'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/hukamnama.dart';

/// Draws the picture the widget picker shows for the Android home screen
/// widget, with the app's real fonts.
///
///     flutter test test/screens/widget_preview_test.dart --tags screens
///     cp build/screens/widget_preview.png \
///        android/app/src/main/res/drawable-nodpi/widget_preview.png
///
/// The picture is an illustration of res/layout/widget_medium.xml, idle. Keep
/// the two alike when either changes. It is for phones before Android 12. Android
/// 12 and newer draw res/layout/widget_preview.xml instead, a still copy of
/// the real layout.
///
/// The Gurbani is in the app's Tiro Gurmukhi, as in the widget. The top line
/// and the button names use Geist here, where the widget uses the phone's own
/// sans, so they will not match to the pixel.
///
/// The Gurbani is the Rahao line of the recorded 2 November 2026 Hukamnama.
void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('widget picker preview', (tester) async {
    final text = Hukamnama.fromSgpc(
      jsonDecode(
        File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );
    final line = hukamnamaPreviewLine(text)!.gurmukhi;

    tester.view.physicalSize = const Size(960, 480);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: _shotKey,
          child: _WidgetIllustration(line: line, ang: text.ang!),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_shotKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/screens/widget_preview.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}

final _shotKey = GlobalKey();

class _WidgetIllustration extends StatelessWidget {
  const _WidgetIllustration({required this.line, required this.ang});

  final String line;
  final int ang;

  @override
  Widget build(BuildContext context) {
    const sans = TextStyle(
      fontFamily: 'Geist',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.none,
    );
    // The widget shrinks the line to fit 2 lines. At the height of this
    // picture (160 dp, over the 48 dp button row) it settles at 16 sp.
    const gurbani = TextStyle(
      fontFamily: 'TiroGurmukhi',
      fontSize: 16,
      color: Palette.foreground,
      decoration: TextDecoration.none,
    );
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The top line: what this is, its day, and its Ang.
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'Hukamnama',
                style: sans.copyWith(color: Palette.gold),
              ),
              TextSpan(
                text: ' · 2 Nov · Ang $ang',
                style: sans.copyWith(color: Palette.muted),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: gurbani,
                ),
              ),
            ),
          ),
          // The two buttons, 40 dp capsules in 48 dp targets.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _Button(
                    name: 'Hukamnama',
                    style: sans.copyWith(fontSize: 14),
                    fill: Palette.surfaceHigh,
                    ink: Palette.foreground,
                    edge: Palette.border,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Button(
                    name: 'Live Kirtan',
                    style: sans.copyWith(fontSize: 14),
                    fill: Palette.gold,
                    ink: Palette.onGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the widget's buttons, idle: a play triangle and its name.
class _Button extends StatelessWidget {
  const _Button({
    required this.name,
    required this.style,
    required this.fill,
    required this.ink,
    this.edge,
  });

  final String name;
  final TextStyle style;
  final Color fill;
  final Color ink;
  final Color? edge;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: edge == null ? null : Border.all(color: edge!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CustomPaint(painter: _PlayTriangle(color: ink)),
          ),
          const SizedBox(width: 6),
          Text(name, style: style.copyWith(color: ink)),
        ],
      ),
    );
  }
}

/// The same triangle as res/drawable/ic_widget_play.xml, scaled to the box it
/// is given. [color] is the tint the layout gives it: dark on the gold button.
class _PlayTriangle extends CustomPainter {
  const _PlayTriangle({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final path = Path()
      ..moveTo(9 * k, 6.2 * k)
      ..lineTo(9 * k, 17.8 * k)
      ..lineTo(19.6 * k, 12 * k)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlayTriangle oldDelegate) => oldDelegate.color != color;
}

Future<void> _loadFonts() async {
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
  await family('TiroGurmukhi', ['assets/fonts/TiroGurmukhi-400.ttf']);
}
