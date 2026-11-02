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
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/live_badge.dart';
import 'package:live_darbar/src/views/widgets/live_status_widget.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';
import 'package:live_darbar/src/views/widgets/source_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// The Hukamnama recording, playing.
const _recording = NowPlaying(
  index: kMukhwakIndex,
  action: PlayAction.pause,
  started: true,
  live: LivePlaybackState(status: LiveStatus.playing, isLiveSource: false),
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
  Size size = const Size(1206, 2622),
}) async {
  tester.view.physicalSize = size;
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

    testWidgets('is there at once, with no fade behind the scrim', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        const Center(child: DataSaverPill()),
        mode: QualityMode.dataSaver,
      );

      for (final transition in [AnimatedSwitcher, FadeTransition]) {
        expect(
          find.descendant(
            of: find.byType(DataSaverPill),
            matching: find.byType(transition),
          ),
          findsNothing,
          reason: '$transition',
        );
      }
      expect(find.text(l10n.quality_data_saver), findsOneWidget);
    });

    testWidgets('opens the quality sheet when tapped', (tester) async {
      final l10n = await _pump(
        tester,
        const Center(child: DataSaverPill()),
        mode: QualityMode.dataSaver,
      );
      expect(find.text(l10n.quality_high_detail), findsNothing);

      await tester.tap(find.byType(DataSaverPill));
      await tester.pumpAndSettle();

      expect(find.text(l10n.quality_high_detail), findsOneWidget);
    });

    testWidgets('is a button the screen reader calls "Data saver"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final l10n = await _pump(
        tester,
        const Center(child: DataSaverPill()),
        mode: QualityMode.dataSaver,
      );

      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(DataSaverPill),
            matching: find.byType(Pressable),
          ),
        ),
        matchesSemantics(
          label: l10n.quality_data_saver,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('is 28 points high and fills on press', (
      tester,
    ) async {
      await _pump(
        tester,
        const Center(child: DataSaverPill()),
        mode: QualityMode.dataSaver,
      );

      expect(tester.getSize(find.byType(DataSaverPill)).height, 28);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DataSaverPill)),
      );
      await tester.pump();
      await tester.pump(Motion.press);
      final fill = tester
          .widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(PressFill),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration as ShapeDecoration;
      expect(fill.color, Palette.surfaceHigh);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('Quality button', () {
    testWidgets('is a waveform and the words "Sound quality"', (tester) async {
      final l10n = await _pump(
        tester,
        const Center(child: QualityButton()),
        mode: QualityMode.automatic,
      );

      expect(find.byIcon(CupertinoIcons.waveform), findsOneWidget);
      expect(find.text(l10n.quality), findsOneWidget);
    });

    testWidgets('is a 32 point capsule inside a 48 point target', (
      tester,
    ) async {
      final l10n = await _pump(
        tester,
        const Center(child: QualityButton()),
        mode: QualityMode.automatic,
      );

      final target = tester.getSize(find.byType(QualityButton));
      expect(target.height, 48);
      expect(target.width, greaterThanOrEqualTo(48));
      final capsule = tester.getSize(
        find.ancestor(
          of: find.text(l10n.quality),
          matching: find.byType(PressFill),
        ),
      );
      expect(capsule.height, 32);
      expect(capsule.width, lessThanOrEqualTo(target.width));
    });

    for (final mode in QualityMode.values) {
      testWidgets('tells the screen reader the mode is ${mode.name}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final l10n = await _pump(
          tester,
          const Center(child: QualityButton()),
          mode: mode,
        );
        final name = switch (mode) {
          QualityMode.automatic => l10n.quality_automatic,
          QualityMode.high => l10n.quality_high,
          QualityMode.dataSaver => l10n.quality_data_saver,
        };

        expect(
          tester.getSemantics(find.byType(QualityButton)),
          matchesSemantics(
            label: l10n.quality,
            value: name,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
          reason: 'one label, not the visible text read again',
        );
        handle.dispose();
      });
    }

    testWidgets('sinks to 0.95 and lights its fill while held', (tester) async {
      await _pump(
        tester,
        const Center(child: QualityButton()),
        mode: QualityMode.automatic,
      );
      Color? fill() => (tester
              .widget<DecoratedBox>(
                find
                    .descendant(
                      of: find.byType(PressFill),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration as ShapeDecoration)
          .color;
      expect(fill(), Palette.surface);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(QualityButton)),
      );
      await tester.pump();
      await tester.pump(Motion.press);

      expect(fill(), Palette.surfaceHigh);
      expect(
        tester
            .widget<AnimatedScale>(
              find.descendant(
                of: find.byType(QualityButton),
                matching: find.byType(AnimatedScale),
              ),
            )
            .scale,
        0.95,
      );
      await gesture.up();
      await tester.pumpAndSettle();
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

  group('Quality sheet', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// Opens the sheet with [mode] chosen and returns its localizations.
    Future<AppLocalizations> openSheet(
      WidgetTester tester,
      QualityMode mode,
    ) async {
      final l10n = await _pump(
        tester,
        const Center(child: QualityButton()),
        mode: mode,
      );
      await tester.tap(find.byType(QualityButton));
      await tester.pumpAndSettle();
      return l10n;
    }

    Finder rowOf(String name) => find.ancestor(
          of: find.text(name),
          matching: find.byType(Pressable),
        );

    Matcher row(String label, {required bool selected}) => matchesSemantics(
          label: label,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasSelectedState: true,
          isSelected: selected,
          isInMutuallyExclusiveGroup: true,
        );

    testWidgets('reads each row once, as its name and what it costs', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final l10n = await openSheet(tester, QualityMode.automatic);

      expect(
        tester.getSemantics(rowOf(l10n.quality_high)),
        row(
          '${l10n.quality_high}, ${l10n.quality_high_detail}',
          selected: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('says which row is selected, and only that one', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final l10n = await openSheet(tester, QualityMode.automatic);

      expect(
        tester.getSemantics(rowOf(l10n.quality_automatic)),
        row(
          '${l10n.quality_automatic}, ${l10n.quality_automatic_detail}',
          selected: true,
        ),
      );
      expect(
        tester.getSemantics(rowOf(l10n.quality_high)),
        row(
          '${l10n.quality_high}, ${l10n.quality_high_detail}',
          selected: false,
        ),
      );
      expect(
        tester.getSemantics(rowOf(l10n.quality_data_saver)),
        row(
          '${l10n.quality_data_saver}, ${l10n.quality_data_saver_detail}',
          selected: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('moves the selected state when another row is tapped', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final l10n = await openSheet(tester, QualityMode.automatic);

      await tester.tap(rowOf(l10n.quality_high));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(rowOf(l10n.quality_high)),
        row(
          '${l10n.quality_high}, ${l10n.quality_high_detail}',
          selected: true,
        ),
      );
      expect(
        tester.getSemantics(rowOf(l10n.quality_automatic)),
        row(
          '${l10n.quality_automatic}, ${l10n.quality_automatic_detail}',
          selected: false,
        ),
      );
      handle.dispose();
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
      expect(size.width - button.right, 24, reason: 'the content margin');
      expect(find.textContaining('${l10n.quality}:'), findsNothing);
    });

    testWidgets('keeps the button on the content column at any width', (
      tester,
    ) async {
      // 1000 points wide: the 460 point column is centred, 270 from each edge.
      final l10n = await _pump(
        tester,
        const NowPlayingScreen(),
        mode: QualityMode.automatic,
        size: const Size(3000, 2400),
      );

      final capsule = tester.getRect(
        find.ancestor(
          of: find.text(l10n.quality),
          matching: find.byType(PressFill),
        ),
      );
      final column = tester.getRect(find.byType(SourceSwitcher));
      expect(column.width, 460);
      expect(capsule.right, column.right);
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
        now: _recording,
      );

      expect(find.byType(QualityButton), findsNothing);
    });

    group('layout', () {
      /// How far the title sits below the artwork. It changes if anything
      /// between them changes height.
      double titleGap(WidgetTester tester, String title) =>
          tester.getTopLeft(find.text(title).first).dy -
          tester.getRect(find.byType(AspectRatio).first).bottom;

      testWidgets('the Data saver pill appearing moves nothing', (
        tester,
      ) async {
        // High is the baseline, not Automatic: on the low tier Automatic adds
        // a "Low quality stream" line below, which recentres the column.
        final l10n = await _pump(
          tester,
          const NowPlayingScreen(),
          mode: QualityMode.high,
        );
        final without = titleGap(tester, l10n.live_kirtan);
        final artworkWithout =
            tester.getTopLeft(find.byType(AspectRatio).first);

        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          const NowPlayingScreen(),
          mode: QualityMode.dataSaver,
        );

        expect(titleGap(tester, l10n.live_kirtan), without);
        expect(
          tester.getTopLeft(find.byType(AspectRatio).first),
          artworkWithout,
          reason: 'and the artwork stays put',
        );
      });

      testWidgets('a recording holds the badge row empty, so nothing moves', (
        tester,
      ) async {
        final l10n = await _pump(
          tester,
          const NowPlayingScreen(),
          mode: QualityMode.dataSaver,
        );
        final live = titleGap(tester, l10n.live_kirtan);

        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          const NowPlayingScreen(),
          mode: QualityMode.dataSaver,
          now: _recording,
        );

        expect(titleGap(tester, l10n.mukhwak), live);
      });
    });
  });
}
