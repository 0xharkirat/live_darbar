import 'package:live_darbar/src/core/store_links.dart';

/// What "Share Live Darbar" sends: 1 line on what the app is, the site, and
/// both stores.
///
/// Plain text only. It lands in WhatsApp, Messages, mail, and anything else
/// the phone offers, and each of them shows a bare link as a link. The labels
/// come from the screen in the reader's language; the links are the fixed
/// constants in store_links.dart, never data from elsewhere.
String appShareText({
  required String message,
  required String playLabel,
  required String appStoreLabel,
}) =>
    [
      message,
      '',
      kSiteUrl,
      '',
      '$playLabel: $kPlayStoreUrl',
      '$appStoreLabel: $kAppStoreUrl',
    ].join('\n');

/// What "Share this Hukamnama" sends: a title with the date, the first line
/// of the shabad in Gurmukhi, and a link to read and hear the rest.
///
/// [firstLine] is sent as it is: Gurmukhi gets no added spacing or marks,
/// which would push the vowel signs off their letters. [more] adds `…` after
/// it, to say the shabad goes on.
String hukamnamaShareText({
  required String title,
  required String firstLine,
  required bool more,
  required String footer,
}) =>
    [
      title,
      '',
      more ? '$firstLine …' : firstLine,
      '',
      '$footer $kSiteUrl',
    ].join('\n');
