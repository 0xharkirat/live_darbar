import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/maintenance.dart';

/// `release.json` may carry 2 optional fields: `minBuild` for each platform,
/// below which the app must update, and `maintenance`, a message for a banner.
/// A file with neither does what the app did before they existed.
void main() {
  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  Map<String, dynamic> fixture(String name) => read('test/fixtures/$name.json');

  /// The same manifest read on [platform], at [build].
  AppUpdate? on(
    TargetPlatform platform,
    Map<String, dynamic> manifest,
    int build,
  ) {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    return AppUpdate.fromManifest(manifest, currentBuild: build);
  }

  group('today\'s web/release.json', () {
    final today = read('web/release.json');

    test('has neither field, so nothing changes', () {
      for (final platform in ['android', 'ios', 'macos']) {
        expect((today[platform] as Map).containsKey('minBuild'), isFalse);
      }
      expect(today.containsKey('maintenance'), isFalse);
    });

    test('offers an older build a soft update, as before', () {
      final update = on(TargetPlatform.android, today, 7)!;

      expect(update.forced, isFalse);
      expect(update.build, 8);
    });

    test('has no maintenance message', () {
      expect(Maintenance.fromManifest(today), isNull);
    });
  });

  group('minBuild', () {
    final forced = fixture('release_forced');

    test('forces an update below it', () {
      final update = on(TargetPlatform.android, forced, 9)!;

      expect(update.forced, isTrue);
      expect(update.version, '3.1.0');
      expect(update.build, 11);
      expect(update.notesEn, ['A fix for a problem that stops playback']);
    });

    test('offers only the fixed store page', () {
      expect(on(TargetPlatform.android, forced, 9)!.storeUrl, kPlayStoreUrl);
      expect(on(TargetPlatform.iOS, forced, 9)!.storeUrl, kAppStoreUrl);
    });

    test('does not force a build that is at the minimum', () {
      final update = on(TargetPlatform.android, forced, 10)!;

      expect(update.forced, isFalse, reason: 'a soft update to build 11');
    });

    test('does not force a build above the minimum, nor offer a current one', () {
      expect(on(TargetPlatform.android, forced, 11), isNull);
      expect(on(TargetPlatform.android, forced, 15), isNull);
    });

    test('is for each platform: macOS has none in this file', () {
      expect(on(TargetPlatform.macOS, forced, 5)!.forced, isFalse);
      expect(on(TargetPlatform.iOS, forced, 5)!.forced, isTrue);
    });

    test('above the newest build is ignored, so nobody is locked out', () {
      final file = fixture('release_min_above_latest');

      final update = on(TargetPlatform.android, file, 9)!;

      expect(update.forced, isFalse);
      expect(update.build, 11);
    });

    test('anything but a whole number from 1 up is ignored', () {
      final file = fixture('release_bad_fields');

      expect(on(TargetPlatform.android, file, 9)!.forced, isFalse); // "10"
      expect(on(TargetPlatform.iOS, file, 9)!.forced, isFalse); // 0
      expect(on(TargetPlatform.macOS, file, 9)!.forced, isFalse); // -3
    });
  });

  group('a forced update is offered whatever was declined', () {
    const soft = AppUpdate(
      version: '3.1.0',
      build: 11,
      storeUrl: kPlayStoreUrl,
      notesEn: [],
      notesPa: [],
    );
    const forced = AppUpdate(
      version: '3.1.0',
      build: 11,
      storeUrl: kPlayStoreUrl,
      notesEn: [],
      notesPa: [],
      forced: true,
    );

    test('a soft update is not offered again after "Not now"', () {
      expect(soft.isOffered(dismissedBuild: 0), isTrue);
      expect(soft.isOffered(dismissedBuild: 11), isFalse);
    });

    test('a forced one is, every launch', () {
      expect(forced.isOffered(dismissedBuild: 0), isTrue);
      expect(forced.isOffered(dismissedBuild: 11), isTrue);
    });
  });

  group('maintenance', () {
    test('reads the message in both languages', () {
      final m = Maintenance.fromManifest(fixture('release_maintenance'))!;

      expect(m.messageFor('en'), startsWith('Live kirtan may stop'));
      expect(m.messageFor('pa'), startsWith('ਅਸੀਂ ਸਟ੍ਰੀਮ'));
    });

    test('shows the other language when 1 is missing', () {
      expect(
        Maintenance.fromManifest({
          'maintenance': {'en': 'English only'},
        })!.messageFor('pa'),
        'English only',
      );
      expect(
        Maintenance.fromManifest({
          'maintenance': {'pa': 'ਸਿਰਫ਼ ਪੰਜਾਬੀ'},
        })!.messageFor('en'),
        'ਸਿਰਫ਼ ਪੰਜਾਬੀ',
      );
    });

    test('takes a string as the message in both languages', () {
      final m = Maintenance.fromManifest({'maintenance': 'Back soon'})!;

      expect(m.messageFor('en'), 'Back soon');
      expect(m.messageFor('pa'), 'Back soon');
    });

    test('is none when the key is missing', () {
      expect(Maintenance.fromManifest({}), isNull);
    });

    test('is none for null, blank, the word "null", or a wrong shape', () {
      expect(Maintenance.fromManifest({'maintenance': null}), isNull);
      expect(Maintenance.fromManifest({'maintenance': ''}), isNull);
      expect(Maintenance.fromManifest({'maintenance': 'null'}), isNull);
      expect(Maintenance.fromManifest({'maintenance': 5}), isNull);
      expect(Maintenance.fromManifest({'maintenance': const []}), isNull);
      expect(Maintenance.fromManifest({'maintenance': const {}}), isNull);
      expect(
        Maintenance.fromManifest(fixture('release_bad_fields')),
        isNull,
      );
    });

    test('does not stop the update check: a file can carry both', () {
      final manifest = {
        ...fixture('release_forced'),
        'maintenance': {'en': 'Back soon'},
      };

      expect(on(TargetPlatform.android, manifest, 9)!.forced, isTrue);
      expect(Maintenance.fromManifest(manifest)!.messageFor('en'), 'Back soon');
    });
  });
}
