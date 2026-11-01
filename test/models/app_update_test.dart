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
      expect(update.storeUrl, kPlayStoreUrl);
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

  group('AppUpdate store url', () {
    // The manifest is fetched over the network, so its links are never used.
    // A host check would not be enough: a Play Store link for another app is
    // still a play.google.com link.
    String urlFor(Object? stores) => AppUpdate.fromManifest(
          manifest(stores: stores),
          currentBuild: 6,
        )!
            .storeUrl;

    final hostile = {
      'a different app on the Play Store':
          'https://play.google.com/store/apps/details?id=com.evil.clone',
      'a different app on the App Store':
          'https://apps.apple.com/us/app/evil/id1',
      'plain http': 'http://play.google.com/store/apps/details?id=x',
      'android intent': 'intent://details?id=x#Intent;scheme=market;end',
      'market scheme': 'market://details?id=x',
      'javascript': 'javascript:alert(1)',
      'file': 'file:///etc/passwd',
      'other host': 'https://example.com/store/apps/details?id=x',
      'look-alike host': 'https://play.google.com.example.com/x',
      'credentials': 'https://play.google.com@example.com/x',
      'not a url': 'http://[::1',
      'blank': '   ',
    };

    for (final entry in hostile.entries) {
      test('android ignores ${entry.key}', () {
        final stores = {'android': entry.value, 'ios': entry.value};
        expect(urlFor(stores), kPlayStoreUrl);
      });
    }

    test('android uses the fixed Play Store page', () {
      expect(urlFor(const <String, dynamic>{}), kPlayStoreUrl);
    });

    test('ios uses the fixed App Store page', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(urlFor(const {'ios': 'https://example.com/x'}), kAppStoreUrl);
    });

    test('macos uses the fixed App Store page', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(urlFor(const {'macos': 'https://example.com/x'}), kAppStoreUrl);
    });

    test('a manifest with no stores block still offers the update', () {
      final json = manifest()..remove('stores');
      final update = AppUpdate.fromManifest(json, currentBuild: 6);
      expect(update, isNotNull);
      expect(update!.storeUrl, kPlayStoreUrl);
    });

    test('a manifest with garbage for stores still offers the update', () {
      expect(urlFor('not a map'), kPlayStoreUrl);
      expect(urlFor(42), kPlayStoreUrl);
      expect(urlFor(null), kPlayStoreUrl);
    });

    test('a well formed link in the manifest is still not followed', () {
      // Even the real-looking, correct-host, correct-scheme case: the link
      // comes from the network, so it is not trusted.
      expect(
        urlFor(const {
          'android': 'https://play.google.com/store/apps/details?id=other'
        }),
        kPlayStoreUrl,
      );
    });

    test('the fixed pages are https links on the store hosts', () {
      final play = Uri.parse(kPlayStoreUrl);
      expect(play.scheme, 'https');
      expect(play.host, 'play.google.com');
      expect(play.queryParameters['id'], 'com.hsi.harki.live_darbar');

      final apple = Uri.parse(kAppStoreUrl);
      expect(apple.scheme, 'https');
      expect(apple.host, 'apps.apple.com');
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
