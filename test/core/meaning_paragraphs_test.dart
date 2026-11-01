import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/meaning_paragraphs.dart';

void main() {
  group('meaningParagraphs', () {
    test('splits English after each verse marker and keeps the marker', () {
      final p = meaningParagraphs(
        'First verse. || 1 || Second verse.  ||  Pause  ||  Last one. || 4 || 5 ||',
      );
      expect(p, [
        'First verse. || 1 ||',
        'Second verse. || Pause ||',
        'Last one. || 4 || 5 ||',
      ]);
    });

    test('splits Punjabi after each verse marker', () {
      final p = meaningParagraphs('ਪਹਿਲੀ ਤੁਕ।੧। ਦੂਜੀ ਤੁਕ। ਰਹਾਉ। ਤੀਜੀ ਤੁਕ । ਰਹਾਉ ਦੂਜਾ ।');
      expect(p, [
        'ਪਹਿਲੀ ਤੁਕ।੧।',
        'ਦੂਜੀ ਤੁਕ।ਰਹਾਉ।',
        'ਤੀਜੀ ਤੁਕ।ਰਹਾਉ ਦੂਜਾ।',
      ]);
    });

    test('a sentence full stop alone does not split', () {
      expect(meaningParagraphs('ਹੇ ਹਰੀ! ਮੇਹਰ ਕਰ। ਨਾਮ ਦੇਹ।੧।'), ['ਹੇ ਹਰੀ! ਮੇਹਰ ਕਰ। ਨਾਮ ਦੇਹ।੧।']);
    });

    test('text with no markers stays 1 paragraph', () {
      expect(meaningParagraphs('  Just text.  '), ['Just text.']);
    });

    test('loses no words on the real SGPC fixtures', () {
      for (final file in [
        'test/fixtures/sgpc_hukamnama_2026_11_02.json',
        'test/fixtures/sgpc_hukamnama_2026_10_16.json',
      ]) {
        final h = jsonDecode(File(file).readAsStringSync())['hukamnama'];
        for (final key in ['ehukamnamadesc', 'ghukamnamadesc']) {
          final text = h[key] as String;
          final words = RegExp(r'[^\s|।]+');
          final before = words.allMatches(text).map((m) => m[0]).toList();
          final after = words
              .allMatches(meaningParagraphs(text).join(' '))
              .map((m) => m[0])
              .toList();
          expect(after, before, reason: '$file $key');
          expect(meaningParagraphs(text).length, greaterThan(3));
        }
      }
    });
  });
}
