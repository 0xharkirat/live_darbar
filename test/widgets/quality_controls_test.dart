import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/quality_mode_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/live_badge.dart';
import 'package:live_darbar/src/views/widgets/live_status_widget.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';

class _Mode extends QualityModeController {
  _Mode(this.mode);

  final QualityMode mode;

  @override
  QualityMode build() {
    ready = Future.value();
    return mode;
  }
}

class _Online extends ConnectivityController {
  @override
  Stream<bool> build() => Stream.value(true);
}

/// The live stream, on the low tier.
const _lowTier = LivePlaybackState(
  status: LiveStatus.playing,
  quality: StreamQuality.low,
);

Future<AppLocalizations> _pump(
  WidgetTester tester,
  Widget home, {
  required QualityMode mode,
  NowPlaying now = const NowPlaying(
    index: kLiveIndex,
    action: PlayAction.stop,
    started: true,
    live: _lowTier,
  ),
}) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        qualityModeProvider.overrideWith(() => _Mode(mode)),
        nowPlayingProvider.overrideWithValue(now),
        livePlaybackProvider.overrideWith((ref) => Stream.value(now.live!)),
        audioProgressProvider.overrideWith(
          (ref) => Stream.value(
            AudioProgressState(
              position: const Duration(minutes: 3),
              bufferedPosition: const Duration(minutes: 6),
              totalDuration: now.isLive ? null : const Duration(minutes: 9),
              isLive: now.isLive,
            ),
          ),
        ),
        connectivityController.overrideWith(_Online.new),
      ],
      child: MaterialApp(
        theme: AppTheme.material,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  group('"Low quality stream" line', () {
    testWidgets('shows when Automatic dropped to the low tier', (tester) async {
      final l10n = await _pump(
        tester,
        const LiveStatusLine(),
        mode: QualityMode.automatic,
      );

      expect(find.text(l10n.low_quality_stream), findsOneWidget);
    });

    testWidgets('stays away when the listener chose Data saver',
        (tester) async {
      final l10n = await _pump(
        tester,
        const LiveStatusLine(),
        mode: QualityMode.dataSaver,
      );

      expect(find.text(l10n.low_quality_stream), findsNothing);
    });

    testWidgets('stays away in High', (tester) async {
      final l10n = await _pump(
        tester,
        const LiveStatusLine(),
        mode: QualityMode.high,
      );

      expect(find.text(l10n.low_quality_stream), findsNothing);
    });
  });

  group('Data saver pill', () {
    testWidgets('shows in Data saver', (tester) async {
      final l10n = await _pump(
        tester,
        const DataSaverPill(),
        mode: QualityMode.dataSaver,
      );

      expect(find.text(l10n.quality_data_saver), findsOneWidget);
    });

    for (final mode in [QualityMode.automatic, QualityMode.high]) {
      testWidgets('is absent in ${mode.name}', (tester) async {
        final l10n = await _pump(tester, const DataSaverPill(), mode: mode);

        expect(find.text(l10n.quality_data_saver), findsNothing);
      });
    }
  });

  group('Quality button', () {
    testWidgets('is an unlabelled icon with a 44 point target', (tester) async {
      final l10n = await _pump(
        tester,
        const Center(child: QualityButton()),
        mode: QualityMode.automatic,
      );

      expect(find.byIcon(CupertinoIcons.slider_horizontal_3), findsOneWidget);
      expect(find.text(l10n.quality), findsNothing, reason: 'no visible label');
      expect(
        find.bySemanticsLabel(l10n.quality),
        findsOneWidget,
        reason: 'but the screen reader names it',
      );
      expect(tester.getSize(find.byType(QualityButton)), const Size(44, 44));
    });

    testWidgets('opens the quality sheet', (tester) async {
      final l10n = await _pump(
        tester,
        const Center(child: QualityButton()),
        mode: QualityMode.automatic,
      );

      await tester.tap(find.byType(QualityButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.quality_high_detail), findsOneWidget);
    });
  });

  group('Now Playing', () {
    testWidgets('puts the button top right and drops the text button', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        const NowPlayingScreen(),
        mode: QualityMode.automatic,
      );

      final size = tester.getSize(find.byType(NowPlayingScreen));
      final button = tester.getRect(find.byType(QualityButton));
      expect(button.top, 0);
      expect(size.width - button.right, 18);
      expect(find.textContaining('${l10n.quality}:'), findsNothing);
    });

    testWidgets('shows the Data saver pill beside the LIVE badge', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        const NowPlayingScreen(),
        mode: QualityMode.dataSaver,
      );

      final pill = tester.getRect(find.text(l10n.quality_data_saver));
      final live = tester.getRect(find.byType(LiveBadge));
      expect(pill.left, greaterThan(live.right));
      expect((pill.center.dy - live.center.dy).abs(), lessThan(6));
      // The status line must not repeat it.
      expect(find.text(l10n.low_quality_stream), findsNothing);
    });

    testWidgets('has no quality button for a recording', (tester) async {
      await _pump(
        tester,
        const NowPlayingScreen(),
        mode: QualityMode.automatic,
        now: const NowPlaying(
          index: kMukhwakIndex,
          action: PlayAction.pause,
          started: true,
          live: LivePlaybackState(
            status: LiveStatus.playing,
            isLiveSource: false,
          ),
        ),
      );

      expect(find.byType(QualityButton), findsNothing);
    });
  });
}
