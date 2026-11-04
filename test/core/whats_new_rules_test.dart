import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/whats_new_rules.dart';

/// "What's new" shows once, on the first open after an update, and never for
/// a fresh install.
void main() {
  group('releaseOf', () {
    test('is the major and minor number', () {
      expect(releaseOf('3.1.0 (11)'), '3.1');
      expect(releaseOf('3.1.4 (15)'), '3.1');
      expect(releaseOf('10.12.0'), '10.12');
    });

    test('is the same for a patch release', () {
      expect(releaseOf('3.1.0 (11)'), releaseOf('3.1.2 (13)'));
    });

    test('is null when there is no version', () {
      expect(releaseOf(''), isNull);
      expect(releaseOf('unknown'), isNull);
      expect(releaseOf('3'), isNull);
    });
  });

  group('decideWhatsNew', () {
    WhatsNewAction decide({
      String? seen,
      String release = '3.1',
      bool hasNotes = true,
      bool existingInstall = true,
    }) =>
        decideWhatsNew(
          seen: seen,
          release: release,
          hasNotes: hasNotes,
          existingInstall: existingInstall,
        );

    test('shows the first open after an update', () {
      expect(decide(seen: '3.0'), WhatsNewAction.show);
    });

    test('shows to a listener who updates from a build that kept no record', () {
      expect(decide(seen: null, existingInstall: true), WhatsNewAction.show);
    });

    test('never again for a release that was shown', () {
      expect(decide(seen: '3.1'), WhatsNewAction.nothing);
    });

    test('shows nothing to a fresh install, and records the release', () {
      expect(
        decide(seen: null, existingInstall: false),
        WhatsNewAction.record,
      );
    });

    test('a fresh install shows nothing even when the release has notes', () {
      expect(
        decide(seen: null, existingInstall: false, hasNotes: true),
        WhatsNewAction.record,
      );
    });

    test('records a release with no notes, and shows nothing', () {
      expect(decide(seen: '3.0', hasNotes: false), WhatsNewAction.record);
      expect(
        decide(seen: null, existingInstall: true, hasNotes: false),
        WhatsNewAction.record,
      );
    });

    test('a release that was seen needs no notes at all', () {
      expect(decide(seen: '3.1', hasNotes: false), WhatsNewAction.nothing);
    });
  });
}
