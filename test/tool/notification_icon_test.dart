// Checks the Android notification icon, the small mark in the status bar and
// on the media and reminder notifications.
//
// Android paints the icon as a silhouette, so the test draws the vector's
// paths the same way: 1 colour, filled, non-zero winding. It then looks at the
// pixels at status bar size for the parts of the Darbar Sahib mark.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _iconFile = 'android/app/src/main/res/drawable/ic_notification.xml';

/// The Material music note that the icon used before 3.1.1.
const _musicNote =
    'M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 '
    '4,4 4,-1.79 4,-4V7h4V3h-6z';

void main() {
  final xml = File(_iconFile).readAsStringSync();
  final paths = RegExp(r'<path\b([^>]*)/>').allMatches(xml).toList();
  final pathData = [
    for (final p in paths) _attribute(p.group(1)!, 'android:pathData')!,
  ];

  test('keeps its name, so both callers and keep.xml still find it', () {
    expect(
      File('lib/src/media_session/live_darbar_audio_handler.dart')
          .readAsStringSync(),
      contains("androidNotificationIcon: 'drawable/ic_notification'"),
    );
    expect(
      File('lib/src/services/reminder_platform.dart').readAsStringSync(),
      contains("_androidIcon = 'ic_notification'"),
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

  test('fills every path with 1 colour, white, and draws no strokes', () {
    expect(paths, isNotEmpty);
    for (final p in paths) {
      expect(_attribute(p.group(1)!, 'android:fillColor'), '#FFFFFFFF');
      expect(p.group(1), isNot(contains('strokeWidth')));
      expect(p.group(1), isNot(contains('fillType')),
          reason: 'cut-outs wind the other way, so the default fill works');
    }
  });

  test('is no longer the music note', () {
    expect(pathData, isNot(contains(_musicNote)));
    final comment = RegExp(r'<!--(.*?)-->', dotAll: true).firstMatch(xml)!;
    expect(comment.group(1)!.toLowerCase(), isNot(contains('music')));
    expect(comment.group(1), contains('Darbar Sahib'));
  });

  test('keeps a 2 unit margin on each side', () {
    final bounds = _toPath(pathData).getBounds();
    expect(bounds.left, greaterThanOrEqualTo(2));
    expect(bounds.top, greaterThanOrEqualTo(2));
    expect(bounds.right, lessThanOrEqualTo(22));
    expect(bounds.bottom, lessThanOrEqualTo(22));
  });

  group('at status bar size, 24 px', () {
    late _Mask mask;

    setUpAll(() async {
      mask = await _Mask.render(_toPath(pathData), 24);
      await _savePreview(_toPath(pathData), 'notification_icon_24', 24);
      await _savePreview(_toPath(pathData), 'notification_icon_96', 96);
    });

    test('shows 3 tops: the central dome and the 2 cupolas', () {
      // Row 6 cuts through the 2 cupola domes and the central dome.
      expect(mask.runs(6), hasLength(3));
    });

    test('shows the 3 finials as separate points', () {
      expect(mask.runs(3), hasLength(3));
    });

    test('shows the door as a cut-out in a solid base', () {
      expect(mask.isInk(12, 19), isFalse, reason: 'the door is open');
      expect(mask.isInk(6, 19), isTrue, reason: 'the wall left of the door');
      expect(mask.isInk(18, 19), isTrue, reason: 'the wall right of it');
    });

    test('is mostly solid, so it does not fill in or fade out', () {
      final ink = mask.inkFraction;
      expect(ink, greaterThan(0.35));
      expect(ink, lessThan(0.75));
    });
  });
}

String? _attribute(String tag, String name) =>
    RegExp('$name="([^"]*)"').firstMatch(tag)?.group(1);

/// Builds 1 path from Android path data.
///
/// It reads the absolute commands M, L, H, V, C, A, and Z, which is all the
/// icon uses. A relative command fails the test, so the margin check stays
/// simple to trust.
ui.Path _toPath(List<String> data) {
  final path = ui.Path();
  for (final d in data) {
    final tokens = RegExp(r'[A-Za-z]|-?\d*\.?\d+')
        .allMatches(d)
        .map((m) => m.group(0)!)
        .toList();
    var i = 0;
    double next() => double.parse(tokens[i++]);
    var command = '';
    var x = 0.0, y = 0.0;
    while (i < tokens.length) {
      if (RegExp('[A-Za-z]').hasMatch(tokens[i])) command = tokens[i++];
      switch (command) {
        case 'M':
          path.moveTo(x = next(), y = next());
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
        default:
          fail('the icon uses "$command"; keep to M, L, H, V, C, A, and Z');
      }
    }
  }
  return path;
}

Future<ui.Image> _draw(ui.Path path, int size, {ui.Color? background}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (background != null) {
    canvas.drawColor(background, ui.BlendMode.src);
  }
  canvas.scale(size / 24);
  canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  return recorder.endRecording().toImage(size, size);
}

Future<void> _savePreview(ui.Path path, String name, int size) async {
  final image = await _draw(path, size, background: const ui.Color(0xFF1B1B1F));
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('build/screens/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
}

/// The icon's alpha channel at 1 size, read as ink or no ink.
class _Mask {
  _Mask(this.size, this.alpha);

  final int size;
  final Uint8List alpha;

  static Future<_Mask> render(ui.Path path, int size) async {
    final image = await _draw(path, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = bytes!.buffer.asUint8List();
    return _Mask(size, Uint8List.fromList([
      for (var i = 3; i < rgba.length; i += 4) rgba[i],
    ]));
  }

  bool isInk(int x, int y) => alpha[y * size + x] >= 128;

  double get inkFraction =>
      alpha.where((a) => a >= 128).length / (size * size);

  /// The separate stretches of ink along row [y].
  List<(int, int)> runs(int y) {
    final out = <(int, int)>[];
    int? start;
    for (var x = 0; x <= size; x++) {
      final ink = x < size && isInk(x, y);
      if (ink && start == null) start = x;
      if (!ink && start != null) {
        out.add((start, x - 1));
        start = null;
      }
    }
    return out;
  }
}
