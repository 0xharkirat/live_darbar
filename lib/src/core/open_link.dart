import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link in the browser, and stays quiet when it cannot.
///
/// Every link in this app hangs off an optional button on the Information
/// screen. A device with no browser, or one that refuses the scheme, is not
/// worth an error the reader can do nothing about, so the failure is swallowed
/// here rather than thrown out of a button callback with nobody waiting to
/// catch it.
Future<void> openLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (!kReleaseMode) debugPrint('[link] could not open $url: $e');
  }
}

/// Opens an https link in the system's in-app browser, and stays quiet when
/// it cannot.
///
/// That is a Chrome Custom Tab on Android and a Safari view on iOS, and a new
/// tab on the web. Both native ones are the real browser, with its downloads
/// and saved sign-ins, shown over the app, so the app carries no WebView and
/// the reader taps back to return.
///
/// When the in-app browser will not open, the link goes to the browser as
/// [openLink] would send it.
Future<void> openLinkInApp(String url) async {
  try {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.inAppBrowserView,
      webOnlyWindowName: '_blank',
    );
    if (opened) return;
  } catch (e) {
    if (!kReleaseMode) debugPrint('[link] in-app browser failed for $url: $e');
  }
  await openLink(url);
}
