import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/text_scale.dart';
import 'package:live_darbar/src/views/browser_title.dart';
import 'package:live_darbar/src/views/widgets/maintenance_banner.dart';
import 'package:live_darbar/src/views/widgets/offline_banner_widget.dart';

/// What `MaterialApp.builder` puts around every route.
///
/// It holds the listener's text size at [kMaxTextScale], and puts the offline
/// banner and the maintenance banner above the page. On the web it also keeps
/// the browser tab's title on the page that is on top ([BrowserTitle]). The banner lives above every route rather than
/// inside HomeScreen, so it is still there when the player dialog or the
/// reader is open. Losing your connection while reading the Mukhwak is
/// exactly when you want to be told.
///
/// The limit wraps the banner too, so the banner is held at the same size as
/// the pages under it. A size below the limit is left as the listener set it.
Widget appBuilder(BuildContext context, Widget? child) {
  return BrowserTitle(
    child: MediaQuery.withClampedTextScaling(
      maxScaleFactor: kMaxTextScale,
      child: Column(
        children: [
          const OfflineBannerWidget(),
          const MaintenanceBanner(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
    ),
  );
}
