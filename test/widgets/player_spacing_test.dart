import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/source_index.dart';
import 'package:live_darbar/src/views/screens/home_screen.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/play_button.dart';
import 'package:live_darbar/src/views/widgets/scrubber.dart';
import 'package:live_darbar/src/views/widgets/source_switcher.dart';

import '../support/app_harness.dart';

/// The full-screen player is 3 groups: the artwork and the title, the timeline
/// and the controls, the source switch and the line about the stream. Parts of
/// a group sit 16 apart and the groups sit 32 apart, so the eye reads 3 things
/// and the rhythm is the same all the way down.

const _within = 16.0;
const _between = 32.0;

Future<void> _open(WidgetTester tester, NowPlaying now) async {
  await pumpApp(tester, now: now);
  showNowPlaying(tester.element(find.byType(HomeScreen)));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

Finder _group(String name) => find.byKey(Key('player_group_$name'));

void main() {
  testWidgets('the live rail starts its bar [barInset] into the timeline', (
    tester,
  ) async {
    await _open(tester, livePlaying);

    final timeline = _rect(tester, find.byType(Timeline));
    final bar = find.descendant(
      of: find.byType(Timeline),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 4,
      ),
    );

    expect(_rect(tester, bar).top - timeline.top, Timeline.barInset);
  });

  for (final (name, now) in [
    ('live', livePlaying),
    ('a recording', recordingPlaying),
  ]) {
    group(name, () {
      testWidgets('has 3 groups, in order', (tester) async {
        await _open(tester, now);

        final title = _rect(tester, _group('title'));
        final controls = _rect(tester, _group('controls'));
        final source = _rect(tester, _group('source'));

        expect(title.bottom, lessThan(controls.top));
        expect(controls.bottom, lessThan(source.top));
      });

      testWidgets('puts 32 between the groups, the same twice', (tester) async {
        await _open(tester, now);

        final title = _rect(tester, _group('title'));
        final controls = _rect(tester, _group('controls'));
        final source = _rect(tester, _group('source'));

        // The first group ends at the bar, as the eye sees it: the timeline's
        // own box starts a little above the bar.
        expect(
          controls.top + Timeline.barInset - title.bottom,
          closeTo(_between, 0.01),
        );
        expect(source.top - controls.bottom, closeTo(_between, 0.01));
      });

      testWidgets('puts 16 between the artwork and the title', (tester) async {
        await _open(tester, now);

        final artwork = _rect(
          tester,
          find.descendant(
            of: _group('title'),
            matching: find.byType(AspectRatio),
          ),
        );
        final group = _rect(tester, _group('title'));
        final title = _rect(
          tester,
          find.descendant(
            of: _group('title'),
            matching: find.byKey(const Key('player_title_row')),
          ),
        );

        expect(group.top, artwork.top);
        expect(title.top - artwork.bottom, closeTo(_within, 0.01));
        expect(group.bottom, title.bottom);
      });

      testWidgets('puts 16 between the timeline and the controls', (
        tester,
      ) async {
        await _open(tester, now);

        final timeline = _rect(tester, find.byType(Timeline));
        // The timeline's box, not its bar, is what the group is made of.
        final play = _rect(
          tester,
          find.descendant(
            of: _group('controls'),
            matching: find.byType(PlayButton),
          ),
        );
        final group = _rect(tester, _group('controls'));

        expect(group.top, timeline.top);
        expect(play.top - timeline.bottom, closeTo(_within, 0.01));
        expect(group.bottom, play.bottom);
      });

      testWidgets('ends with the source switch, at the group\'s foot', (
        tester,
      ) async {
        await _open(tester, now);

        final switcher = _rect(tester, find.byType(SourceSwitcher));
        final group = _rect(tester, _group('source'));

        expect(group.bottom, switcher.bottom);
        expect(group.top, switcher.top, reason: 'no status line, no gap');
      });
    });
  }

  testWidgets('the line about the stream sits 8 above the switch while it shows',
      (tester) async {
    await _open(
      tester,
      const NowPlaying(
        index: kLiveIndex,
        action: PlayAction.stop,
        started: true,
        live: LivePlaybackState(
          status: LiveStatus.failed,
          reconnectAttempt: 1,
        ),
      ),
    );

    // The mini player on home says the same, so look inside the group.
    final text = find.descendant(
      of: _group('source'),
      matching: find.text('Reconnecting…'),
    );
    final line = _rect(tester, text);
    final switcher = _rect(tester, find.byType(SourceSwitcher));
    final controls = _rect(tester, _group('controls'));
    final source = _rect(tester, _group('source'));

    expect(switcher.top - line.bottom, greaterThanOrEqualTo(8));
    expect(source.top - controls.bottom, closeTo(_between, 0.01));
    expect(source.bottom, switcher.bottom);
  });
}
