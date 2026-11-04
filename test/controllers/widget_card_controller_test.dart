import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/widget_card_controller.dart';
import 'package:live_darbar/src/controllers/widget_placement_controller.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_widget_install.dart';

/// The facts behind the "add the widget" card: when the listener first plays
/// the Hukamnama, what is saved, and what the phone says about the widget.
/// The rules that turn them into a card are in widget_card_rules_test.dart.
void main() {
  late FakeWidgetInstall phone;

  /// What the player is doing, which a test changes.
  late NowPlayingStub player;

  ProviderContainer containerFor({FakeWidgetInstall? install}) {
    final container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        widgetInstallProvider.overrideWithValue(install ?? phone),
        widgetCardSettleProvider.overrideWithValue(Duration.zero),
        nowPlayingProvider.overrideWith((ref) => ref.watch(_playerProvider)),
        _playerProvider.overrideWith(() => player),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<WidgetCardState> stateOf(ProviderContainer container) =>
      container.read(widgetCardProvider.future);

  WidgetCardController controllerOf(ProviderContainer container) =>
      container.read(widgetCardProvider.notifier);

  Future<void> saved(String key, bool? expected) async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(key), expected, reason: key);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    phone = FakeWidgetInstall();
    player = NowPlayingStub();
  });

  group('the first play of the Hukamnama', () {
    test('a new listener has played nothing, and no visit is a later visit',
        () async {
      final container = containerFor();
      final state = await stateOf(container);

      expect(state.played, isFalse);
      expect(state.shown, isFalse);
      expect(state.dismissed, isFalse);
      expect(state.laterVisit, isFalse);
      expect(container.read(widgetPlacementProvider), WidgetPlacement.unknown);
    });

    test('is saved when the recording starts to play', () async {
      final container = containerFor();
      await stateOf(container);

      player.set(_recording(playing: true));
      await Future<void>.delayed(Duration.zero);
      await stateOf(container);

      expect((await stateOf(container)).played, isTrue);
      await saved(WidgetCardController.playedKey, true);
    });

    test('is not made a later visit by the play itself', () async {
      final container = containerFor();
      await stateOf(container);

      player.set(_recording(playing: true));
      await Future<void>.delayed(Duration.zero);

      expect((await stateOf(container)).laterVisit, isFalse);
    });

    test('is not saved for live kirtan or the Katha', () async {
      final container = containerFor();
      await stateOf(container);

      player.set(_live(playing: true));
      await Future<void>.delayed(Duration.zero);
      player.set(_katha(playing: true));
      await Future<void>.delayed(Duration.zero);

      expect((await stateOf(container)).played, isFalse);
      await saved(WidgetCardController.playedKey, null);
    });

    test('is not saved while the recording is only selected', () async {
      final container = containerFor();
      await stateOf(container);

      player.set(_recording(playing: false));
      await Future<void>.delayed(Duration.zero);

      expect((await stateOf(container)).played, isFalse);
    });

    test('is saved when the recording already plays as the card starts',
        () async {
      // A widget or the car started the app, and the sound began before the
      // saved facts had loaded.
      player = NowPlayingStub(_recording(playing: true));
      final container = containerFor();

      await controllerOf(container).start();

      expect((await stateOf(container)).played, isTrue);
      await saved(WidgetCardController.playedKey, true);
    });
  });

  group('a later visit', () {
    test('is the next start of the app after the first play', () async {
      SharedPreferences.setMockInitialValues({
        WidgetCardController.playedKey: true,
      });

      final state = await stateOf(containerFor());

      expect(state.played, isTrue);
      expect(state.laterVisit, isTrue);
    });

    test('is the next return to the front after the first play', () async {
      final container = containerFor();
      await stateOf(container);
      player.set(_recording(playing: true));
      await Future<void>.delayed(Duration.zero);

      await controllerOf(container).resumed();

      expect((await stateOf(container)).laterVisit, isTrue);
    });

    test('a return to the front before any play is not one', () async {
      final container = containerFor();
      await stateOf(container);

      await controllerOf(container).resumed();

      expect((await stateOf(container)).laterVisit, isFalse);
    });
  });

  group('once', () {
    test('is saved the moment the card shows', () async {
      final container = containerFor();
      await stateOf(container);

      await controllerOf(container).markShown();

      final state = await stateOf(container);
      expect(state.shown, isTrue);
      expect(state.showing, isTrue);
      await saved(WidgetCardController.shownKey, true);
    });

    test('an app that starts again has shown it, and is not showing it',
        () async {
      SharedPreferences.setMockInitialValues({
        WidgetCardController.playedKey: true,
        WidgetCardController.shownKey: true,
      });

      final state = await stateOf(containerFor());
      final facts = state.facts(
        supported: true,
        placement: WidgetPlacement.absent,
        sheetOpen: false,
      );

      expect(facts.shownEarlier, isTrue);
      expect(facts.showing, isFalse);
    });

    test('"Not now" is saved for good', () async {
      final container = containerFor();
      await stateOf(container);
      await controllerOf(container).markShown();

      await controllerOf(container).dismiss();

      final state = await stateOf(container);
      expect(state.dismissed, isTrue);
      expect(state.showing, isFalse);
      await saved(WidgetCardController.dismissedKey, true);

      // A new start of the app reads it back.
      expect((await stateOf(containerFor())).dismissed, isTrue);
    });
  });

  group('the widget on the home screen', () {
    test('is asked after the card has waited for the launch', () async {
      phone.placementNow = WidgetPlacement.absent;
      final container = containerFor();

      await controllerOf(container).start();

      expect(container.read(widgetPlacementProvider), WidgetPlacement.absent);
      expect(phone.placementCount, 1);
    });

    test('is asked again when the app comes to the front', () async {
      final container = containerFor();
      await controllerOf(container).start();
      expect(container.read(widgetPlacementProvider), WidgetPlacement.absent);

      // The listener went to the home screen and added the widget.
      phone.placementNow = WidgetPlacement.added;
      await controllerOf(container).resumed();

      expect(container.read(widgetPlacementProvider), WidgetPlacement.added);
    });

    test('stays unknown when the phone cannot say', () async {
      phone.placementError = StateError('no plugin');
      final container = containerFor();

      await controllerOf(container).start();

      expect(container.read(widgetPlacementProvider), WidgetPlacement.unknown);
    });

    test('is not asked where there are no home screen widgets', () async {
      final web = FakeWidgetInstall(supported: false);
      final container = containerFor(install: web);

      await controllerOf(container).start();

      expect(web.placementCount, 0);
      expect(container.read(widgetPlacementProvider), WidgetPlacement.unknown);
    });
  });

  group('adding the widget', () {
    test('Android asks the phone to pin it, and needs no steps', () async {
      final container = containerFor();

      final asked =
          await container.read(widgetPlacementProvider.notifier).add();

      expect(asked, isTrue);
      expect(phone.pinCount, 1);
    });

    test('a launcher that cannot pin needs the steps', () async {
      phone.pinSupported = false;
      final container = containerFor();

      final asked =
          await container.read(widgetPlacementProvider.notifier).add();

      expect(asked, isFalse);
      expect(phone.pinCount, 0);
    });

    test('an iPhone has no call for it, and needs the steps', () async {
      phone.iphone = true;
      final container = containerFor();

      final asked =
          await container.read(widgetPlacementProvider.notifier).add();

      expect(asked, isFalse);
      expect(phone.pinCount, 0);
    });

    test('looks again at once, so Android that added it shows', () async {
      final container = containerFor();
      phone.placementNow = WidgetPlacement.added;

      await container.read(widgetPlacementProvider.notifier).add();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(widgetPlacementProvider), WidgetPlacement.added);
    });
  });
}

NowPlaying _recording({required bool playing}) => NowPlaying(
      index: kMukhwakIndex,
      action: playing ? PlayAction.pause : PlayAction.play,
      started: playing,
      live: const LivePlaybackState(isLiveSource: false),
    );

NowPlaying _katha({required bool playing}) => NowPlaying(
      index: kKathaIndex,
      action: playing ? PlayAction.pause : PlayAction.play,
      started: playing,
      live: const LivePlaybackState(isLiveSource: false),
    );

NowPlaying _live({required bool playing}) => NowPlaying(
      index: kLiveIndex,
      action: playing ? PlayAction.stop : PlayAction.play,
      started: playing,
      live: const LivePlaybackState(status: LiveStatus.playing),
    );

/// Holds what the player is doing, for a test to change.
class NowPlayingStub extends Notifier<NowPlaying> {
  NowPlayingStub([NowPlaying? initial])
      : _initial = initial ??
            const NowPlaying(
              index: kLiveIndex,
              action: PlayAction.play,
              started: false,
              live: LivePlaybackState(),
            );

  final NowPlaying _initial;

  @override
  NowPlaying build() => _initial;

  void set(NowPlaying value) => state = value;
}

final _playerProvider = NotifierProvider<NowPlayingStub, NowPlaying>(
  () => throw UnimplementedError('Each test overrides the player.'),
);
