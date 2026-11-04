import 'package:flutter/foundation.dart';

/// Whether the home screen widget is on the phone's home screen, as far as the
/// app can tell.
enum WidgetPlacement {
  /// Not asked yet, or the phone could not say. The card stays away, because
  /// it must never offer a widget that is already there.
  unknown,

  /// Asked, and no Live Darbar widget is on the home screen.
  absent,

  /// At least 1 Live Darbar widget is on the home screen.
  added,
}

/// Everything [shouldShowWidgetCard] decides from.
@immutable
class WidgetCardFacts {
  const WidgetCardFacts({
    required this.supported,
    required this.playedHukamnama,
    required this.laterVisit,
    required this.dismissed,
    required this.shownEarlier,
    required this.showing,
    required this.placement,
    required this.sheetOpen,
  });

  /// The platform has home screen widgets: Android and iPhone. The web has
  /// none.
  final bool supported;

  /// The listener has played the Hukamnama recording at least once. The app
  /// saves this when that playback starts.
  final bool playedHukamnama;

  /// This is a later visit to Home than the one that played the recording: the
  /// app started again, or came back to the front, after the first play. The
  /// card never appears while the listener is still on the visit that played.
  final bool laterVisit;

  /// The listener tapped "Not now".
  final bool dismissed;

  /// The card was on screen in an earlier visit of the app and the listener
  /// did not answer. It shows once, so it does not come back.
  final bool shownEarlier;

  /// The card is on screen now, in this visit of the app. It stays until the
  /// listener answers or the widget is added.
  final bool showing;

  final WidgetPlacement placement;

  /// A sheet or a page is open over Home.
  final bool sheetOpen;
}

/// Whether Home shows the "add the widget" card.
///
/// The card is a one-time, calm offer. It shows when all of these hold:
///
/// - The platform has widgets, and the listener has not tapped "Not now".
/// - The widget is not on the home screen. A phone that cannot say counts as
///   not sure, and the card waits.
/// - The listener played the Hukamnama recording on an earlier visit, so the
///   card comes after the app has proved useful, not on the first launch.
/// - It has not been shown, and left unanswered, on an earlier visit. The About
///   screen keeps a row for the listener who wants the widget later.
/// - No sheet is open. A card that appears under a sheet is wasted on the 1
///   time. A card that is already on screen stays: a sheet over it does not
///   move the page.
bool shouldShowWidgetCard(WidgetCardFacts f) {
  if (!f.supported || f.dismissed) return false;
  if (f.placement != WidgetPlacement.absent) return false;
  if (f.showing) return true;
  return f.playedHukamnama && f.laterVisit && !f.shownEarlier && !f.sheetOpen;
}
