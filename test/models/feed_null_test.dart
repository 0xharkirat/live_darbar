import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';

/// A feed that writes the word "null" for a missing value must read the same
/// as one that writes nothing. Each model drops it, so nothing past the model
/// can show it.
void main() {
  Map<String, dynamic> sgpc([Map<String, Object?> changes = const {}]) {
    final json = jsonDecode(
      File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final body = json['hukamnama'] as Map<String, dynamic>;
    body.addAll(changes);
    return json;
  }

  group('Hukamnama.fromSgpc', () {
    test('drops "null" in every optional field, as it drops blank', () {
      final h = Hukamnama.fromSgpc(
        sgpc({
          'gheading1': 'null',
          'eheading1': 'NULL',
          'ghukamnamadesc': ' null ',
          'ehukamnamadesc': 'null',
          'gfooter1': 'null',
          'efooter1': 'null',
        }),
      );

      expect(h.headingGurmukhi, isNull);
      expect(h.headingEnglish, isNull);
      expect(h.punjabiMeaning, isNull);
      expect(h.englishMeaning, isNull);
      expect(h.footerGurmukhi, isNull);
      expect(h.footerEnglish, isNull);
    });

    test('drops a heading line that is "null" and keeps the other', () {
      final h = Hukamnama.fromSgpc(
        sgpc({'gheading1': 'null', 'gheading2': 'ਧਨਾਸਰੀ ਮਹਲਾ ੪॥'}),
      );

      expect(h.headingGurmukhi, 'ਧਨਾਸਰੀ ਮਹਲਾ ੪॥');
    });

    test('has no Ang when the Ang is "null"', () {
      expect(Hukamnama.fromSgpc(sgpc({'ang': 'null'})).ang, isNull);
    });

    test('refuses a text that is only "null", as it refuses an empty one', () {
      expect(
        () => Hukamnama.fromSgpc(sgpc({'ghukamnama': 'null'})),
        throwsFormatException,
      );
    });

    test('keeps the real text of the recorded response', () {
      final h = Hukamnama.fromSgpc(sgpc());

      expect(h.headingGurmukhi, isNotNull);
      expect(h.englishMeaning, isNotNull);
      expect(h.ang, 668);
    });
  });

  group('Hukamnama read back from disk', () {
    test('drops "null" that an older build stored', () {
      final stored = Hukamnama.fromSgpc(sgpc()).toJson();
      stored['englishMeaning'] = 'null';
      stored['headingEnglish'] = 'null';

      final h = Hukamnama.fromJson(stored);

      expect(h.englishMeaning, isNull);
      expect(h.headingEnglish, isNull);
      expect(h.punjabiMeaning, isNotNull);
    });
  });

  group('SgpcEvent', () {
    Map<String, dynamic> event(Map<String, Object?> changes) => {
          'id': 'ns558-004',
          'gregorian': '2026-11-05',
          'titlePa': 'ਸਿਰਲੇਖ',
          'titleEn': 'Title',
          ...changes,
        };

    test('has no English title when it is "null"', () {
      expect(SgpcEvent.fromJson(event({'titleEn': 'null'})).titleEn, isNull);
    });

    test('is refused with no Punjabi title, "null" included', () {
      expect(
        () => SgpcEvent.fromJson(event({'titlePa': 'null'})),
        throwsFormatException,
      );
    });

    test('keeps real titles', () {
      final e = SgpcEvent.fromJson(event({}));
      expect(e.titlePa, 'ਸਿਰਲੇਖ');
      expect(e.titleEn, 'Title');
    });
  });

  group('AppUpdate notes', () {
    test('leave out a note that is "null" or blank', () {
      final update = AppUpdate.fromManifest(
        {
          'android': {'build': 99, 'version': '9.9.9'},
          'ios': {'build': 99, 'version': '9.9.9'},
          'macos': {'build': 99, 'version': '9.9.9'},
          'notes': {
            'en': ['A real note.', 'null', '  ', 'NULL'],
            'pa': ['null'],
          },
        },
        currentBuild: 1,
      );

      expect(update, isNotNull);
      expect(update!.notesEn, ['A real note.']);
      expect(update.notesPa, isEmpty);
    });
  });
}
