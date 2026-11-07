import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/barah_maha.dart';
import 'package:live_darbar/src/models/sikh_date.dart';

/// The Sangrand Hukamnama: on the 1st of each Sikh month the sangat reads the
/// pauri of Barah Maha Maajh for that month. assets/data/barah_maha.json holds
/// the bani, written from the Shabad OS database by tool/barah_maha.dart.
void main() {
  BarahMaha load() => BarahMaha.fromJson(
        jsonDecode(File('assets/data/barah_maha.json').readAsStringSync())
            as Map<String, dynamic>,
      );

  test('has the title lines, with ੴ and its meanings', () {
    final heading = load().heading;
    expect([
      for (final l in heading) l.gurmukhi
    ], [
      'ਬਾਰਹ ਮਾਹਾ ਮਾਂਝ ਮਹਲਾ ੫ ਘਰੁ ੪ ॥',
      'ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥',
    ]);
    expect(heading[1].english, startsWith('One Universal Creator God'));
    // Prof. Sahib Singh gives no Punjabi meaning for this ੴ line.
    expect(heading[1].punjabi, isNull);
  });

  test('has 14 pauris, each ending with its own number', () {
    final pauris = load().pauris;
    expect(pauris, hasLength(14));
    for (final (i, pauri) in pauris.indexed) {
      expect(pauri.last.gurmukhi, contains('॥${toGurmukhiNumerals(i + 1)}॥'),
          reason: 'pauri ${i + 1}');
    }
  });

  test('gives each month its own pauri', () {
    final bani = load();
    expect(bani.pauriFor(0).first.gurmukhi, startsWith('ਚੇਤਿ'), reason: 'Chet');
    expect(bani.pauriFor(7).first.gurmukhi, startsWith('ਕਤਿਕਿ'),
        reason: 'Katak');
    expect(bani.pauriFor(11).first.gurmukhi, startsWith('ਫਲਗੁਣਿ'),
        reason: 'Phagun');
    expect(bani.pauriFor(7).first.ang, 135);
  });

  test('has the Punjabi and the English meaning of every line', () {
    for (final pauri in load().pauris) {
      for (final line in pauri) {
        expect(line.english, isNotNull, reason: line.gurmukhi);
        expect(line.punjabi, isNotNull, reason: line.gurmukhi);
      }
    }
  });

  test('names who wrote the meanings and the pauses', () {
    final credits = load().credits;
    expect(credits['english'], 'Dr. Sant Singh Khalsa');
    expect(credits['punjabi'], startsWith('Prof. Sahib Singh'));
    expect(credits['vishraam'], isNotNull);
  });

  test('refuses a file with the wrong number of pauris', () {
    final json = jsonDecode(
      File('assets/data/barah_maha.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    (json['pauris'] as List).removeLast();
    expect(() => BarahMaha.fromJson(json), throwsFormatException);
  });
}
