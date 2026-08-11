import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/app_update.dart';

/// A manifest shaped like the real one at darbar.live/version.json.
Map<String, dynamic> manifest({
  int build = 9,
  String version = '2.1.0',
  Object? stores = const {
    'android': 'https://play.google.com/store/apps/details?id=x',
    'ios': 'https://apps.apple.com/us/app/x/id1',
    'macos': 'https://apps.apple.com/us/app/x/id1',
  },
  Object? notes = const {
    'en': ['Faster live kirtan'],
    'pa': ['ਤੇਜ਼ ਲਾਈਵ ਕੀਰਤਨ'],
  },
}) {
  return {
    'android': {'version': version, 'build': build},
    'ios': {'version': version, 'build': build},
    'macos': {'version': version, 'build': build},
    'stores': stores,
    'notes': notes,
  };
}

void main() {
  // These run on the Dart VM, where defaultTargetPlatform reports the host.
  // Pin it so the platform lookup is deterministic rather than dependent on
  // whoever runs the suite.
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('AppUpdate.fromManifest', () {
    test('offers a genuinely newer build', () {
      final update = AppUpdate.fromManifest(manifest(build: 9), currentBuild: 6);
      expect(update, isNotNull);
      expect(update!.build, 9);
      expect(update.version, '2.1.0');
      expect(update.storeUrl, contains('play.google.com'));
    });

    test('says nothing when the installed build is current', () {
      expect(AppUpdate.fromManifest(manifest(build: 6), currentBuild: 6), isNull);
    });

    test('says nothing when the installed build is somehow newer', () {
      // Happens on internal builds and sideloads. Offering a "newer" release
      // that is actually older would send someone backwards.
      expect(AppUpdate.fromManifest(manifest(build: 5), currentBuild: 6), isNull);
    });

    test('compares build numbers, not version strings', () {
      // The point of comparing integers: "2.10.0" sorts before "2.9.0" as text,
      // which is a bug that only shows up at the tenth minor release.
      final update = AppUpdate.fromManifest(
        manifest(build: 20, version: '2.10.0'),
        currentBuild: 19,
      );
      expect(update, isNotNull);
      expect(update!.version, '2.10.0');
    });
  });

  group('AppUpdate.fromManifest rejects broken manifests', () {
    test('missing store url', () {
      expect(
        AppUpdate.fromManifest(manifest(stores: const {}), currentBuild: 6),
        isNull,
      );
    });

    test('build number sent as a string', () {
      final broken = manifest();
      broken['android'] = {'version': '2.1.0', 'build': '9'};
      expect(AppUpdate.fromManifest(broken, currentBuild: 6), isNull);
    });

    test('platform entry missing entirely', () {
      final broken = manifest();
      broken.remove('android');
      expect(AppUpdate.fromManifest(broken, currentBuild: 6), isNull);
    });

    test('garbage where the notes should be', () {
      // A malformed notes block must not cost the user the update prompt.
      final update = AppUpdate.fromManifest(
        manifest(notes: 'not a map'),
        currentBuild: 6,
      );
      expect(update, isNotNull);
      expect(update!.notesEn, isEmpty);
    });
  });

  group('AppUpdate.notesFor', () {
    test('picks Punjabi when asked and available', () {
      final update = AppUpdate.fromManifest(manifest(), currentBuild: 6)!;
      expect(update.notesFor('pa'), ['ਤੇਜ਼ ਲਾਈਵ ਕੀਰਤਨ']);
      expect(update.notesFor('en'), ['Faster live kirtan']);
    });

    test('falls back to English rather than showing nothing', () {
      final update = AppUpdate.fromManifest(
        manifest(notes: const {
          'en': ['Only English this time']
        }),
        currentBuild: 6,
      )!;
      expect(update.notesFor('pa'), ['Only English this time']);
    });
  });
}
