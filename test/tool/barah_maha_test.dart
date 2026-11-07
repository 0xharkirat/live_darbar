import 'package:flutter_test/flutter_test.dart';

import '../../tool/barah_maha.dart';

/// The rule that cuts Barah Maha into its pauris. The real file it writes,
/// assets/data/barah_maha.json, is checked in test/models/barah_maha_test.dart.
void main() {
  group('splitPauris', () {
    test('ends each pauri at the line with its number', () {
      final pauris = splitPauris([
        'ਕਿਰਤਿ ਕਰਮ ਕੇ ਵੀਛੁੜੇ; ਕਰਿ ਕਿਰਪਾ ਮੇਲਹੁ ਰਾਮ ॥',
        'ਹਰਿ ਮੇਲਹੁ ਸੁਆਮੀ ਸੰਗਿ ਪ੍ਰਭ; ਜਿਸ ਕਾ ਨਿਹਚਲ ਧਾਮ ॥੧॥',
        'ਚੇਤਿ ਗੋਵਿੰਦੁ ਅਰਾਧੀਐ; ਹੋਵੈ ਅਨੰਦੁ ਘਣਾ ॥',
        'ਚੇਤਿ ਮਿਲਾਏ ਸੋ ਪ੍ਰਭੂ; ਤਿਸ ਕੈ ਪਾਇ ਲਗਾ ॥੨॥',
      ]);
      expect(pauris, hasLength(2));
      expect(pauris[0], hasLength(2));
      expect(pauris[1].first, startsWith('ਚੇਤਿ'));
    });

    test('reads the last pauri, which ends with the shabad number too', () {
      // Barah Maha's last line: ਨਾਨਕੁ ਮੰਗੈ ਦਰਸ ਦਾਨੁ; ਕਿਰਪਾ ਕਰਹੁ ਹਰੇ ॥੧੪॥੧॥
      final pauris = splitPauris(['ਇਕ ॥੧॥', 'ਦੋ;', 'ਅੰਤ ॥੨॥੧॥']);
      expect(pauris, hasLength(2));
      expect(pauris.last, ['ਦੋ;', 'ਅੰਤ ॥੨॥੧॥']);
    });

    test('refuses lines after the last number, or a number out of order', () {
      expect(
        () => splitPauris(['ਇਕ ॥੧॥', 'ਦੋ ॥']),
        throwsFormatException,
        reason: 'a line with no pauri',
      );
      expect(
        () => splitPauris(['ਇਕ ॥੧॥', 'ਤਿੰਨ ॥੩॥']),
        throwsFormatException,
        reason: 'pauri 2 is missing',
      );
    });
  });
}
