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
