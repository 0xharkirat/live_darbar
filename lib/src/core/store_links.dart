import 'package:live_darbar/src/models/sgpc_day.dart';

/// Where the app lives in each store, and the other fixed links it opens.
///
/// Fixed constants on purpose: a link the app opens should never come from
/// data that someone else could change.
const kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.hsi.harki.live_darbar';
const kAppStoreUrl = 'https://apps.apple.com/us/app/live-darbar/id6449766130';
const kPrivacyPolicyUrl =
    'https://www.freeprivacypolicy.com/live/04ba243a-1119-41eb-a8cd-30e8e95fcf4f';
const kFeedbackUrl = 'https://forms.gle/HKZtyYzdEYstgbby7';

/// The Live Darbar site. The web app, served from /app/ on it, links back.
const kSiteUrl = 'https://darbar.live';

/// The Hukamnama reader on the web, which "Share this Hukamnama" sends. It
/// opens the day's Hukamnama, whatever the day the link is opened. A web build
/// from before 7 November 2026 opens Home at this address, so the link never
/// breaks.
const kHukamnamaWebUrl = '$kSiteUrl/app/hukamnama';

/// The reader on the web for one earlier day: [kHukamnamaWebUrl], a slash and
/// `YYYY-MM-DD`. "Share this Hukamnama" sends it for an earlier day, so the
/// link opens the shabad that was shared and not the one of the day it is
/// opened. The web keeps the last 30 days, so an old link shows a calm note.
String hukamnamaWebUrlOn(DateTime day) =>
    '$kHukamnamaWebUrl/${sgpcDayIso(day)}';

/// The app's id on the App Store, the number at the end of [kAppStoreUrl]. The
/// rate row hands it to the store so the App Store opens on this app.
const kAppStoreId = '6449766130';
