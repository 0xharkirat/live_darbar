// Checks the Android notification icon, the small mark in the status bar and
// on the media and reminder notifications.
//
// Android paints the icon as a silhouette. The icon is 1 path, so the test
// draws it the way Android does: 1 colour, filled, non-zero winding. It then
// looks at the pixels at status bar sizes for the parts of the Darbar Sahib
// mark.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _iconFile = 'android/app/src/main/res/drawable/ic_notification.xml';

/// The Material music note that the icon used before.
const _musicNote =
    'M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 '
    '4,4 4,-1.79 4,-4V7h4V3h-6z';

void main() {
  late String xml;
  late String tag;
  late String pathData;

  setUpAll(() {
    xml = File(_iconFile).readAsStringSync();
    final paths = RegExp(r'<path\b([^>]*)/>').allMatches(xml).toList();
    expect(paths, hasLength(1), reason: 'the mark is 1 self-closing <path>');
    expect('<path'.allMatches(xml), hasLength(1));
    tag = paths.single.group(1)!;
    pathData = _attribute(tag, 'android:pathData') ?? '';
    expect(pathData, isNotEmpty, reason: 'the <path> needs android:pathData');
  });

  test('keeps its name, so the media notification and keep.xml find it', () {
    // reminder_platform_test.dart checks the reminder side at run time.
    expect(
      File(
        'lib/src/media_session/live_darbar_audio_handler.dart',
      ).readAsStringSync(),
      contains("androidNotificationIcon: 'drawable/ic_notification'"),
    );
    expect(
      File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
      contains('@drawable/ic_notification'),
    );
  });

  test('is a 24 dp vector on a 24 by 24 viewport', () {
    expect(xml, contains('android:width="24dp"'));
    expect(xml, contains('android:height="24dp"'));
    expect(xml, contains('android:viewportWidth="24"'));
    expect(xml, contains('android:viewportHeight="24"'));
  });

  test('fills 1 white path with nothing that changes how Android draws it', () {
    expect(_attribute(tag, 'android:fillColor'), '#FFFFFFFF');
    for (final attribute in [
      'strokeWidth',
      'strokeColor',
      'fillAlpha',
      'fillType',
    ]) {
      expect(tag, isNot(contains(attribute)));
    }
    for (final element in ['<group', '<clip-path']) {
      expect(xml, isNot(contains(element)));
    }
  });

  test('is no longer the music note', () {
    expect(pathData, isNot(_musicNote));
    expect(xml.toLowerCase(), isNot(contains('music')));
  });

  test('keeps a 2 unit margin on each side', () {
    final bounds = _toPath(pathData).getBounds();
    expect(bounds.left, greaterThanOrEqualTo(2));
    expect(bounds.top, greaterThanOrEqualTo(2));
    expect(bounds.right, lessThanOrEqualTo(22));
    expect(bounds.bottom, lessThanOrEqualTo(22));
  });

  // 24 px is the status bar icon at 1x. 17 px is about the size that the
  // notification shade header draws it at.
  for (final size in [24, 17]) {
    group('at $size px', () {
      late _Mask mask;

      setUpAll(() async => mask = await _Mask.render(_toPath(pathData), size));

      test('shows 3 tops: the central dome and the 2 cupolas', () {
        expect(mask.runsAt(6.5), hasLength(3));
      });

      test('shows the 3 finials as separate points', () {
        expect(mask.runsAt(3.5), hasLength(3));
      });

      test('shows an arched door cut into a solid wall', () {
        expect(mask.isInkAt(12, 19.5), isFalse, reason: 'the door is open');
        expect(mask.isInkAt(12, 15), isFalse, reason: 'the arch is open');
        expect(mask.isInkAt(5.5, 19.5), isTrue, reason: 'the wall left of it');
        expect(mask.isInkAt(18.5, 19.5), isTrue, reason: 'the wall right');
      });

      test('is solid enough to read, and not a filled square', () {
        expect(mask.inkFraction, inInclusiveRange(0.35, 0.75));
      });
    });
  }

  test('writes previews to build/screens for a person to look at', () async {
    for (final size in [24, 96]) {
      final png = await _png(_toPath(pathData), size);
      File('build/screens/notification_icon_$size.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png);
    }
  });
}

String? _attribute(String tag, String name) =>
    RegExp('$name="([^"]*)"').firstMatch(tag)?.group(1);

/// Builds a path from Android path data.
///
/// It reads the absolute commands M, L, H, V, C, A, and Z, which is all the
/// icon uses. Any other command, or a number with no command, fails the test.
ui.Path _toPath(String data) {
  final path = ui.Path();
  final tokens = RegExp(
    r'[A-Za-z]|-?\d*\.?\d+',
  ).allMatches(data).map((m) => m.group(0)!).toList();
  var i = 0;
  double next() => double.parse(tokens[i++]);
  var command = '';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  while (i < tokens.length) {
    if (RegExp('[A-Za-z]').hasMatch(tokens[i])) command = tokens[i++];
    switch (command) {
      case 'M':
        path.moveTo(startX = x = next(), startY = y = next());
        command = 'L';
      case 'L':
        path.lineTo(x = next(), y = next());
      case 'H':
        path.lineTo(x = next(), y);
      case 'V':
        path.lineTo(x, y = next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), x = next(), y = next());
      case 'A':
        final rx = next(), ry = next(), rotation = next();
        final large = next() != 0, sweep = next() != 0;
        path.arcToPoint(
          ui.Offset(x = next(), y = next()),
          radius: ui.Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        (x, y) = (startX, startY);
        // A number straight after Z has no command, so the next round fails.
        command = '';
      default:
        fail('the icon uses "$command" at token $i; keep to M L H V C A Z');
    }
  }
  return path;
}

Future<ui.Image> _draw(ui.Path path, int size, {ui.Color? background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (background != null) canvas.drawColor(background, ui.BlendMode.src);
  canvas.scale(size / 24);
  canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(size, size);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _bytes(ui.Image image, ui.ImageByteFormat format) async {
  try {
    final data = await image.toByteData(format: format);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<Uint8List> _png(ui.Path path, int size) async => _bytes(
      await _draw(path, size, background: const ui.Color(0xFF1B1B1F)),
      ui.ImageByteFormat.png,
    );

/// The icon's alpha channel at 1 size, read as ink or no ink.
///
/// The methods take viewport units, 0 to 24, and look at the pixel there.
class _Mask {
  _Mask(this.size, this.alpha);

  final int size;
  final Uint8List alpha;

  static Future<_Mask> render(ui.Path path, int size) async {
    final rgba = await _bytes(
      await _draw(path, size),
      ui.ImageByteFormat.rawRgba,
    );
    final alpha = Uint8List(size * size);
    for (var i = 0; i < alpha.length; i++) {
      alpha[i] = rgba[i * 4 + 3];
    }
    return _Mask(size, alpha);
  }

  int _pixel(double units) => (units * size / 24).floor();

  bool _isInk(int x, int y) => alpha[y * size + x] >= 128;

  bool isInkAt(double x, double y) => _isInk(_pixel(x), _pixel(y));

  double get inkFraction => alpha.where((a) => a >= 128).length / alpha.length;

  /// The separate stretches of ink along the pixel row at [y] units.
  List<(int, int)> runsAt(double y) {
    final row = _pixel(y);
    final out = <(int, int)>[];
    int? start;
    for (var x = 0; x <= size; x++) {
      final ink = x < size && _isInk(x, row);
      if (ink && start == null) start = x;
      if (!ink && start != null) {
        out.add((start, x - 1));
        start = null;
      }
    }
    return out;
  }
}
