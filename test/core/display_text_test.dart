import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/display_text.dart';

/// Text from SGPC's feed, or from release.json, is shown to a listener. A
/// missing value must show as nothing, never as the word "null".
void main() {
  group('displayText', () {
    test('keeps real text, trimmed', () {
      expect(displayText('Ang 668'), 'Ang 668');
      expect(displayText('  ਹਰਿ ਹਰਿ  '), 'ਹਰਿ ਹਰਿ');
    });

    test('hides null', () => expect(displayText(null), isNull));

    test('hides an empty string and white space', () {
      expect(displayText(''), isNull);
      expect(displayText('   '), isNull);
      expect(displayText('\n\t '), isNull);
    });

    test('hides the word "null" that a server writes for a missing value', () {
      expect(displayText('null'), isNull);
      expect(displayText('NULL'), isNull);
      expect(displayText('Null'), isNull);
      expect(displayText('  null\n'), isNull);
    });

    test('keeps text that only contains or starts with the word', () {
      expect(displayText('nullable'), 'nullable');
      expect(displayText('null and void'), 'null and void');
      expect(displayText('Annulled'), 'Annulled');
    });

    test('hides a value that is not a string', () {
      expect(displayText(5), isNull);
      expect(displayText(true), isNull);
      expect(displayText(const ['a']), isNull);
    });
  });

  group('on a String?', () {
    test('isUsable says whether there is anything to show', () {
      const String? none = null;
      expect(none.isUsable, isFalse);
      expect(''.isUsable, isFalse);
      expect('null'.isUsable, isFalse);
      expect('ਸਤਿ'.isUsable, isTrue);
    });

    test('usable is the trimmed text, or null', () {
      const String? none = null;
      expect(none.usable, isNull);
      expect(' x '.usable, 'x');
      expect('null'.usable, isNull);
    });

    test('orPlaceholder gives a dash by default', () {
      const String? none = null;
      expect(none.orPlaceholder(), '–');
      expect('null'.orPlaceholder(), '–');
      expect('Ang 668'.orPlaceholder(), 'Ang 668');
    });

    test('orPlaceholder takes another placeholder', () {
      expect(''.orPlaceholder('N/A'), 'N/A');
    });
  });
}
