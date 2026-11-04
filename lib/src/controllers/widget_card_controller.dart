import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/controllers/widget_placement_controller.dart';
import 'package:live_darbar/src/models/source_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long Home waits after the app starts, or comes to the front, before it
/// decides about the card. The sheet that the app opens at launch (the update
/// offer) comes first, so the card never shows for a moment and then goes
/// under it.
final widgetCardSettleProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 1500),
);

/// What the app knows for the "add the widget" card.
@immutable
class WidgetCardState {
  const WidgetCardState({
    this.played = false,
    this.shown = false,
    this.dismissed = false,
    this.laterVisit = false,
    this.showing = false,
  });

  /// Saved. The listener has played the Hukamnama recording.
  final bool played;

  /// Saved. The card has been on screen once.
  final bool shown;

  /// Saved. The listener tapped "Not now".
  final bool dismissed;

  /// In memory. See [WidgetCardFacts.laterVisit].
  final bool laterVisit;

  /// In memory. The card is on screen in this visit of the app.
  final bool showing;

  WidgetCardState copyWith({
    bool? played,
    bool? shown,
    bool? dismissed,
    bool? laterVisit,
    bool? showing,
  }) =>
      WidgetCardState(
        played: played ?? this.played,
        shown: shown ?? this.shown,
        dismissed: dismissed ?? this.dismissed,
        laterVisit: laterVisit ?? this.laterVisit,
        showing: showing ?? this.showing,
      );

  /// The facts for [shouldShowWidgetCard]. [placement] is the phone's to say
  /// (see [WidgetPlacementController]), and [sheetOpen] is the screen's.
  WidgetCardFacts facts({
    required bool supported,
    required WidgetPlacement placement,
    required bool sheetOpen,
  }) =>
      WidgetCardFacts(
        supported: supported,
        playedHukamnama: played,
        laterVisit: laterVisit,
        dismissed: dismissed,
        shownEarlier: shown && !showing,
        showing: showing,
        placement: placement,
        sheetOpen: sheetOpen,
      );
}

/// The "add the widget" card on Home, and the "Home screen widget" row in
/// About.
///
/// It saves 1 fact when the listener plays the Hukamnama recording for the
/// first time, from any place: a tile, the player, the notification, the car,
/// the widget. A later visit to Home may then show the card, once. See
/// [shouldShowWidgetCard] for every rule.
///
/// Whether the widget is on the home screen is [WidgetPlacementController]'s,
/// which this asks again at launch and when the app comes to the front.
class WidgetCardController extends AsyncNotifier<WidgetCardState> {
  static const playedKey = 'widget_card_played';
  static const shownKey = 'widget_card_shown';
  static const dismissedKey = 'widget_card_dismissed';

  /// The state as it is now, once the saved facts have loaded. Read it right
  /// before a change, with no wait between, so 2 jobs cannot overwrite each
  /// other. Null when the app has let the controller go, as a job that a tap
  /// started and did not wait for can find.
  Future<WidgetCardState?> _loaded() async {
    if (!ref.mounted) return null;
    await future;
    return ref.mounted ? state.requireValue : null;
  }

  @override
  Future<WidgetCardState> build() async {
    ref.listen<NowPlaying>(nowPlayingProvider, (_, next) {
      if (_isHukamnamaPlaying(next)) unawaited(markPlayed());
    });

    final prefs = await SharedPreferences.getInstance();
    final played = prefs.getBool(playedKey) ?? false;
    return WidgetCardState(
      played: played,
      shown: prefs.getBool(shownKey) ?? false,
      dismissed: prefs.getBool(dismissedKey) ?? false,
      // The app starting is a visit. If the recording was played before it
      // started, this visit is a later one.
      laterVisit: played,
    );
  }

  /// The recording is playing: the source is the Hukamnama and the sound is on.
  bool _isHukamnamaPlaying(NowPlaying now) =>
      now.index == kMukhwakIndex && now.isPlaying;

  /// Looks at the player once, after the saved facts have loaded. A play can
  /// start before they do, for instance from a widget that started the app.
  Future<void> _catchUp() async {
    if (!ref.mounted) return;
    if (_isHukamnamaPlaying(ref.read(nowPlayingProvider))) await markPlayed();
  }

  /// The first time the recording plays. The card waits for a later visit, so
  /// this does not make [WidgetCardState.laterVisit] true.
  Future<void> markPlayed() async {
    final current = await _loaded();
    if (current == null || current.played) return;
    state = AsyncData(current.copyWith(played: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(playedKey, true);
  }

  /// Home started. Waits for [widgetCardSettleProvider], then asks the phone
  /// whether the widget is there.
  Future<void> start() async {
    if (await _loaded() == null) return;
    await _catchUp();
    await check();
  }

  /// The app came back to the front. That is a later visit to Home, if the
  /// recording has played.
  Future<void> resumed() async {
    final current = await _loaded();
    if (current != null && current.played && !current.laterVisit) {
      state = AsyncData(current.copyWith(laterVisit: true));
    }
    await check();
  }

  /// Waits for the sheets of a launch, then asks the phone where the widget is.
  ///
  /// The wait is a timer that stops when the app lets the controller go, so a
  /// screen that is gone leaves nothing running.
  Future<void> check() async {
    if (!ref.mounted) return;
    final waited = Completer<void>();
    final timer = Timer(ref.read(widgetCardSettleProvider), waited.complete);
    ref.onDispose(timer.cancel);
    await waited.future;
    if (!ref.mounted) return;
    await ref.read(widgetPlacementProvider.notifier).refresh();
  }

  /// The card is on screen. Saved at once, so the card shows once, whatever
  /// the listener does next.
  Future<void> markShown() async {
    final current = await _loaded();
    if (current == null || current.showing) return;
    state = AsyncData(current.copyWith(shown: true, showing: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(shownKey, true);
  }

  /// "Not now": the card never comes back.
  Future<void> dismiss() async {
    final current = await _loaded();
    if (current == null) return;
    state = AsyncData(current.copyWith(dismissed: true, showing: false));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(dismissedKey, true);
  }
}

final widgetCardProvider =
    AsyncNotifierProvider<WidgetCardController, WidgetCardState>(
  WidgetCardController.new,
);
