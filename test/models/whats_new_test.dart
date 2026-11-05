import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/whats_new.dart';

/// The notes of a release are 1 file in `assets/whats_new/`. The next release
/// adds a file and no code, so every file that ships must read.
void main() {
  Map<String, Object?> item(String n) => {
        'title': {'en': 'Title $n', 'pa': 'ਸਿਰਲੇਖ $n'},
        'body': {'en': 'Body $n', 'pa': 'ਵੇਰਵਾ $n'},
      };

  group('WhatsNew.fromJson', () {
    test('reads the release and each item in both languages', () {
      final notes = WhatsNew.fromJson({
        'release': '3.1',
        'items': [item('1'), item('2'), item('3')],
      })!;

      expect(notes.release, '3.1');
      expect(notes.items, hasLength(3));
      expect(notes.items[1].titleFor('en'), 'Title 2');
      expect(notes.items[1].titleFor('pa'), 'ਸਿਰਲੇਖ 2');
      expect(notes.items[1].bodyFor('en'), 'Body 2');
      expect(notes.items[1].bodyFor('pa'), 'ਵੇਰਵਾ 2');
    });

    test('keeps only the first 5 items: the sheet is calm', () {
      final notes = WhatsNew.fromJson({
        'release': '3.1',
        'items': [for (var i = 1; i <= 8; i++) item('$i')],
      })!;

      expect(notes.items, hasLength(WhatsNew.maxItems));
      expect(notes.items.last.titleEn, 'Title 5');
    });

    test('drops an item with no title in either language', () {
      final notes = WhatsNew.fromJson({
        'release': '3.1',
        'items': [
          item('1'),
          {'title': {'en': 'Only English'}},
          {'title': {'pa': 'ਸਿਰਫ਼ ਪੰਜਾਬੀ'}},
          {'title': {'en': 'null', 'pa': 'ਸਿਰਲੇਖ'}},
          'not an item',
          item('2'),
        ],
      })!;

      expect(notes.items.map((i) => i.titleEn), ['Title 1', 'Title 2']);
    });

    test('the body is optional, and "null" is no body', () {
      final notes = WhatsNew.fromJson({
        'release': '3.1',
        'items': [
          {
            'title': {'en': 'A', 'pa': 'ਉ'},
            'body': {'en': 'null', 'pa': ''},
          },
          {
            'title': {'en': 'B', 'pa': 'ਅ'},
          },
        ],
      })!;

      expect(notes.items[0].bodyEn, isNull);
      expect(notes.items[0].bodyPa, isNull);
      expect(notes.items[1].bodyEn, isNull);
    });

    test('is null with no release, no items, or no usable item', () {
      expect(WhatsNew.fromJson(null), isNull);
      expect(WhatsNew.fromJson('text'), isNull);
      expect(WhatsNew.fromJson({'items': [item('1')]}), isNull);
      expect(WhatsNew.fromJson({'release': 'null', 'items': [item('1')]}), isNull);
      expect(WhatsNew.fromJson({'release': '3.1'}), isNull);
      expect(WhatsNew.fromJson({'release': '3.1', 'items': []}), isNull);
      expect(
        WhatsNew.fromJson({
          'release': '3.1',
          'items': [
            {'title': {}},
          ],
        }),
        isNull,
      );
    });

    test('an item with "only" shows on those platforms and nowhere else', () {
      final json = {
        'release': '3.1',
        'items': [
          item('all'),
          {...item('ios'), 'only': ['ios']},
          {...item('phones'), 'only': ['android', 'ios']},
          {...item('one name'), 'only': 'android'},
        ],
      };
      List<String> titles(String platform) => WhatsNew.fromJson(
            json,
            platform: platform,
          )!
              .items
              .map((i) => i.titleEn)
              .toList();

      expect(titles('ios'), ['Title all', 'Title ios', 'Title phones']);
      expect(
        titles('android'),
        ['Title all', 'Title phones', 'Title one name'],
      );
      expect(titles('web'), ['Title all']);
    });

    test('is null when no item is for this platform', () {
      expect(
        WhatsNew.fromJson(
          {
            'release': '3.1',
            'items': [
              {...item('1'), 'only': ['ios']},
            ],
          },
          platform: 'web',
        ),
        isNull,
      );
    });

    test('counts the 5 after it leaves out the other platforms', () {
      final notes = WhatsNew.fromJson(
        {
          'release': '3.1',
          'items': [
            for (var n = 0; n < 3; n++) {...item('ios $n'), 'only': ['ios']},
            for (var n = 0; n < 5; n++) item('$n'),
          ],
        },
        platform: 'android',
      )!;
      expect(notes.items.map((i) => i.titleEn), [
        for (var n = 0; n < 5; n++) 'Title $n',
      ]);
    });

    test('names the platform the way "only" spells it', () {
      expect(whatsNewPlatform(web: true, target: TargetPlatform.iOS), 'web');
      expect(whatsNewPlatform(web: false, target: TargetPlatform.iOS), 'ios');
      expect(
        whatsNewPlatform(web: false, target: TargetPlatform.android),
        'android',
      );
      expect(
        whatsNewPlatform(web: false, target: TargetPlatform.macOS),
        'macos',
      );
    });
  });

  group('the files that ship', () {
    final files = Directory('assets/whats_new')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    test('there is 1 for release 3.1', () {
      expect(files.map((f) => f.uri.pathSegments.last), contains('3.1.json'));
    });

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final release = name.substring(0, name.length - '.json'.length);

      group(name, () {
        final notes = WhatsNew.fromJson(jsonDecode(file.readAsStringSync()));

        test('is named for the release it holds', () {
          expect(release, matches(RegExp(r'^\d+\.\d+$')));
          expect(notes, isNotNull);
          expect(notes!.release, release);
        });

        // Each phone gets 3 to 5. The web has no widget and no reminder, so it
        // may get fewer, but never none.
        for (final (platform, least) in [('android', 3), ('ios', 3), ('web', 1)]) {
          test('has $least to 5 new things on $platform, as the sheet is calm',
              () {
            final mine = WhatsNew.fromJson(
              jsonDecode(file.readAsStringSync()),
              platform: platform,
            );
            expect(mine, isNotNull);
            expect(mine!.items.length, inInclusiveRange(least, 5));
          });
        }

        test('names only platforms that the app knows in "only"', () {
          final json = jsonDecode(file.readAsStringSync()) as Map;
          for (final item in json['items'] as List) {
            final only = (item as Map)['only'];
            if (only == null) continue;
            expect(
              only is List ? only : [only],
              everyElement(isIn(['android', 'ios', 'web', 'macos'])),
            );
          }
        });

        test('keeps every thing short, and says each in both languages', () {
          for (final item in notes!.items) {
            expect(item.titleEn.split(' ').length, lessThanOrEqualTo(10));
            expect(item.bodyEn, isNotNull, reason: item.titleEn);
            expect(item.bodyPa, isNotNull, reason: item.titleEn);
            expect(item.bodyEn!.split(' ').length, lessThanOrEqualTo(20));
          }
        });

        test('has no 2 things with the same title', () {
          final titles = notes!.items.map((i) => i.titleEn).toList();
          expect(titles.toSet(), hasLength(titles.length));
        });
      });
    }
  });
}
