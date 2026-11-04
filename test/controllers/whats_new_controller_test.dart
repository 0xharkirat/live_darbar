import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/controllers/whats_new_controller.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/models/whats_new.dart';
import 'package:shared_preferences/shared_preferences.dart';

WhatsNew _notes(String release) => WhatsNew(
      release: release,
      items: const [
        WhatsNewItem(titleEn: 'One', titlePa: 'ਇੱਕ'),
        WhatsNewItem(titleEn: 'Two', titlePa: 'ਦੋ'),
        WhatsNewItem(titleEn: 'Three', titlePa: 'ਤਿੰਨ'),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A container for an app of [version] whose releases with notes are
  /// [withNotes].
  ProviderContainer container({
    String version = '3.1.0 (11)',
    Set<String> withNotes = const {'3.1'},
  }) {
    final c = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWith((ref) async => version),
        whatsNewLoaderProvider.overrideWithValue(
          (release) async => withNotes.contains(release) ? _notes(release) : null,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<String?> seen() async =>
      (await SharedPreferences.getInstance()).getString(
        WhatsNewController.seenKey,
      );

  test('the first open after an update returns the notes', () async {
    SharedPreferences.setMockInitialValues({'whats_new_seen_release': '3.0'});
    final c = container();

    final notes = await c.read(whatsNewController.future);

    expect(notes?.release, '3.1');
    expect(notes?.items, hasLength(3));
    // Not marked until the sheet is on screen.
    expect(await seen(), '3.0');
  });

  test('returns the notes to a listener whose old build kept no record', () async {
    SharedPreferences.setMockInitialValues({'locale': 'pa'});
    final c = container();

    expect((await c.read(whatsNewController.future))?.release, '3.1');
  });

  test('a fresh install gets nothing, and the release is recorded', () async {
    SharedPreferences.setMockInitialValues({});
    final c = container();

    expect(await c.read(whatsNewController.future), isNull);
    expect(await seen(), '3.1');
  });

  test('a fresh install then updated gets the next release', () async {
    SharedPreferences.setMockInitialValues({});
    await container().read(whatsNewController.future);

    final next = container(
      version: '3.2.0 (12)',
      withNotes: {'3.1', '3.2'},
    );

    expect((await next.read(whatsNewController.future))?.release, '3.2');
  });

  test('markSeen saves the release, so it never shows again', () async {
    SharedPreferences.setMockInitialValues({'whats_new_seen_release': '3.0'});
    final c = container();
    await c.read(whatsNewController.future);

    await c.read(whatsNewController.notifier).markSeen();

    expect(c.read(whatsNewController).value, isNull);
    expect(await seen(), '3.1');

    // The next launch.
    final again = container();
    expect(await again.read(whatsNewController.future), isNull);
  });

  test('a release that was seen returns nothing', () async {
    SharedPreferences.setMockInitialValues({'whats_new_seen_release': '3.1'});

    expect(await container().read(whatsNewController.future), isNull);
  });

  test('a patch release is the same release', () async {
    SharedPreferences.setMockInitialValues({'whats_new_seen_release': '3.1'});
    final c = container(version: '3.1.3 (14)');

    expect(await c.read(whatsNewController.future), isNull);
  });

  test('a release with no notes returns nothing, and is recorded', () async {
    SharedPreferences.setMockInitialValues({'whats_new_seen_release': '3.0'});
    final c = container(version: '3.2.0 (12)');

    expect(await c.read(whatsNewController.future), isNull);
    expect(await seen(), '3.2');
  });

  test('returns nothing when the platform gives no version', () async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final c = container(version: 'unknown');

    expect(await c.read(whatsNewController.future), isNull);
    expect(await seen(), isNull);
  });

  group('loadWhatsNew', () {
    test('reads the file that ships for 3.1', () async {
      final notes = await loadWhatsNew(rootBundle, '3.1');

      expect(notes?.release, '3.1');
      expect(notes?.items.length, inInclusiveRange(3, 5));
    });

    test('is null for a release with no file', () async {
      expect(await loadWhatsNew(rootBundle, '0.1'), isNull);
    });
  });
}
