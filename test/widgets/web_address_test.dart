import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hark, 7 November: "remove the hash symbol from flutter web". The web app's
/// addresses read `darbar.live/app/hukamnama`, not `darbar.live/app/#/hukamnama`.
///
/// The parts live in 3 files that nothing compiles together, so these tests
/// read them. A browser check of the built site is in the PR.
void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final index = File('web/index.html').readAsStringSync();
  final hosting = (jsonDecode(File('firebase.json').readAsStringSync())
      as Map<String, dynamic>)['hosting'] as Map<String, dynamic>;

  test('the app writes the page into the path, before it starts', () {
    final strategy = main.indexOf('usePathUrlStrategy()');
    expect(strategy, isNot(-1), reason: 'no usePathUrlStrategy() in main');
    // bootstrap() starts the app (lib/src/bootstrap.dart calls runApp).
    expect(strategy, lessThan(main.indexOf('return bootstrap<')),
        reason: 'it must run before the first route is read');
  });

  test('the host answers every page address with the app', () {
    // A reload of /app/hukamnama must load the app, not a 404.
    final rewrites = (hosting['rewrites'] as List).cast<Map<String, dynamic>>();
    expect(
      rewrites,
      contains(
        allOf(
          containsPair('source', '/app/**'),
          containsPair('destination', '/app/index.html'),
        ),
      ),
    );
  });

  group('an old address with a #', () {
    final script = RegExp(
      r'<script id="legacy-hash-address">([\s\S]*?)</script>',
    ).firstMatch(index);

    test('is moved into the path before Flutter starts', () {
      expect(script, isNotNull, reason: 'no legacy-hash-address script');
      expect(
        index.indexOf('legacy-hash-address'),
        lessThan(index.indexOf('flutter_bootstrap.js')),
      );
      final code = script!.group(1)!;
      expect(code, contains('location.hash'));
      expect(code, contains('history.replaceState'));
      // The app is served from /app/, so the base href leads the path.
      expect(code, contains("querySelector('base')"));
    });
  });
}
