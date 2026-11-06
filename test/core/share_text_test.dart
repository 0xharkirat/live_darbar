import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/share_text.dart';
import 'package:live_darbar/src/core/store_links.dart';

/// The plain text that the share sheet sends.
void main() {
  test('the app text has the site and both stores', () {
    final text = appShareText(
      message: 'Live kirtan.',
      playLabel: 'Google Play Store',
      appStoreLabel: 'Apple App Store',
    );
    expect(text, startsWith('Live kirtan.\n'));
    expect(text, contains(kSiteUrl));
    expect(text, contains('Google Play Store: $kPlayStoreUrl'));
    expect(text, contains('Apple App Store: $kAppStoreUrl'));
  });

  test('the Hukamnama text keeps the Gurmukhi line as it is', () {
    const line = 'ਸੋਰਠਿ ਮਹਲਾ ੫ ॥';
    final text = hukamnamaShareText(
      title: 'Hukamnama from Sri Darbar Sahib, 6 November',
      firstLine: line,
      more: true,
      footer: 'Read it all and listen:',
    );
    expect(
      text,
      'Hukamnama from Sri Darbar Sahib, 6 November\n'
      '\n'
      '$line …\n'
      '\n'
      'Read it all and listen: $kSiteUrl',
    );
  });

  test('a 1 line shabad gets no ellipsis', () {
    final text = hukamnamaShareText(
      title: 't',
      firstLine: 'ੴ',
      more: false,
      footer: 'f',
    );
    expect(text, isNot(contains('…')));
  });
}
