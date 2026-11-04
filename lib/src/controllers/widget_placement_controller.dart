import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';

/// Whether the home screen widget is on the phone's home screen, and the way to
/// ask for it.
///
/// The card on Home and the row in About share it. It knows nothing about the
/// player or the card's rules, so About can use it alone.
///
/// The answer is asked for again at launch, when the app comes to the front,
/// and when About opens. So the card goes away after the listener adds the
/// widget, and About says "Added".
class WidgetPlacementController extends Notifier<WidgetPlacement> {
  WidgetInstall get _install => ref.read(widgetInstallProvider);

  @override
  WidgetPlacement build() => WidgetPlacement.unknown;

  /// Asks the phone now whether the widget is on the home screen. When the
  /// phone cannot say, the answer is [WidgetPlacement.unknown], and the card
  /// stays away.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final install = _install;
    if (!install.isSupported) return;
    var placement = WidgetPlacement.unknown;
    try {
      placement = await install.placement();
    } catch (e) {
      debugPrint('[widget] could not tell if the widget is added: $e');
    }
    if (ref.mounted) state = placement;
  }

  /// "Add widget", from the card or from About.
  ///
  /// Returns true when the phone took the request: Android shows its own
  /// dialog. Returns false when the listener must do it by hand, on an iPhone
  /// or on an Android launcher that cannot pin, and the screen shows the steps.
  Future<bool> add() async {
    final asked = await _install.requestPin();
    // Android may have added the widget by now. If the listener is still in
    // its dialog, the check on return to the front finds it.
    unawaited(refresh());
    return asked;
  }
}

final widgetPlacementProvider =
    NotifierProvider<WidgetPlacementController, WidgetPlacement>(
  WidgetPlacementController.new,
);
