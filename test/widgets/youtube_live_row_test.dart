import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/youtube_live_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/youtube_live.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/youtube_live_service.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/youtube_live_row.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/app_harness.dart';

/// Stands in for the platform behind `url_launcher` and records each launch.
class _FakeLauncher extends UrlLauncherPlatform {
  _FakeLauncher({this.error});

  /// When set, every launch throws it, as a phone with no app for the link.
  final Object? error;
  final launches = <({String url, PreferredLaunchMode mode})>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url: url, mode: options.mode));
    if (error != null) throw error!;
    return true;
  }
}

/// The file on the `youtube-live` branch, as the phone reads it. A test sets
/// [body] (null is a 404) or [error], and counts the [calls] the app makes.
class _Published {
  _Published([this.body]);

  /// The text of the file. Null is a file that is not there.
  String? body;

  /// When set, every request throws it, as a phone that is offline.
  Object? error;

  /// When set, every request waits for it before it answers.
  Completer<void>? gate;

  /// The status code of the answer when [body] is set.
  int status = 200;

  int calls = 0;

  late final service = YoutubeLiveService(
    client: MockClient((request) async {
      calls++;
      await gate?.future;
      if (error != null) throw error!;
      final text = body;
      if (text == null) return http.Response('404: Not Found', 404);
      return http.Response(text, status);
    }),
  );
}

/// One stream in the published file.
Map<String, Object?> _entry(String kind, String id) => {
      'videoId': id,
      'kind': kind,
      'title': 'Official SGPC LIVE ($kind)',
      'url': 'https://www.youtube.com/watch?v=$id',
    };

/// The app goes to the background, the way the system walks it there.
void _leave(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  addTearDown(() => _return(tester));
}

/// And back to the front.
void _return(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.resumed) return;
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    if (tester.binding.lifecycleState == state) continue;
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

const _kirtanId = 'AbCdEfGhIjK';
const _kathaId = 'KkKkKkKkKkK';
const _audioId = '7M4WO8CokSA';
String _watch(String id) => 'https://www.youtube.com/watch?v=$id';

/// The published file, checked [ago] before [now].
String _file(
  DateTime now,
  List<Map<String, Object?>> live, {
  Duration ago = const Duration(minutes: 1),
}) =>
    jsonEncode({
      'checkedAt': now.subtract(ago).toUtc().toIso8601String(),
      'channelId': kYoutubeChannelId,
      'live': live,
    });

/// The "Watch live on YouTube" row on Home. It follows the answer that a
/// GitHub Action publishes every 5 minutes: shown when a kirtan or katha video
/// stream is on, hidden when there is none, and a tap opens that video. With
/// no fresh answer it falls back to the time windows in which SGPC is likely
/// to be streaming (India time), and a tap opens the channel's live page.
void main() {
  late UrlLauncherPlatform original;
  setUp(() => original = UrlLauncherPlatform.instance);
  tearDown(() => UrlLauncherPlatform.instance = original);

  /// [hour]:[minute] India time on 7 November 2026, as an instant.
  DateTime ist(int hour, int minute, [int second = 0]) =>
      DateTime.utc(2026, 11, 7, hour, minute, second).subtract(kIndiaOffset);

  const label = 'Watch live on YouTube';
  const spoken = 'Watch live video from Sri Harmandir Sahib on YouTube. '
      'Opens the YouTube app.';
  final row = find.byType(YoutubeLiveRow);
  final pressable = find.descendant(of: row, matching: find.byType(Pressable));

  /// Pumps the row, and lets the first request to the published file end.
  /// With no [published], the file is not there (404): the timetable rules.
  Future<void> pumpRow(
    WidgetTester tester, {
    required DateTime Function() clock,
    String locale = 'en',
    _Published? published,
  }) async {
    final file = published ?? _Published();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          youtubeLiveServiceProvider.overrideWithValue(file.service),
        ],
        child: MaterialApp(
          theme: AppTheme.material,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: YoutubeLiveRow()),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the row finish opening or closing.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 400));

  group('outside a window', () {
    testWidgets('shows nothing, and takes no room', (tester) async {
      await pumpRow(tester, clock: () => ist(10, 0));

      expect(find.text(label), findsNothing);
      expect(pressable, findsNothing);
      expect(tester.getSize(row).height, 0);
    });

    testWidgets('shows nothing 1 minute before the morning window', (
      tester,
    ) async {
      await pumpRow(tester, clock: () => ist(3, 59));

      expect(find.text(label), findsNothing);
    });
  });

  group('inside a window', () {
    testWidgets('shows the label, a gold play icon and the leaves-app arrow', (
      tester,
    ) async {
      await pumpRow(tester, clock: () => ist(4, 0));

      expect(find.text(label), findsOneWidget);
      final play = tester.widget<Icon>(
        find.descendant(
          of: row,
          matching: find.byIcon(CupertinoIcons.play_rectangle),
        ),
      );
      expect(play.color, Palette.gold);
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(CupertinoIcons.arrow_up_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('says it in Punjabi', (tester) async {
      await pumpRow(tester, clock: () => ist(13, 0), locale: 'pa');

      expect(find.text('YouTube ਉੱਤੇ ਲਾਈਵ ਦੇਖੋ'), findsOneWidget);
      expect(find.text(label), findsNothing);
    });

    testWidgets('is a target of 44 points or more', (tester) async {
      await pumpRow(tester, clock: () => ist(17, 30));

      expect(tester.getSize(pressable).height, greaterThanOrEqualTo(44));
    });

    testWidgets('the screen reader hears 1 button, with the full sentence', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, clock: () => ist(5, 0));

      expect(
        tester.getSemantics(pressable),
        matchesSemantics(
          label: spoken,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('the screen reader hears it in Punjabi too', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRow(tester, clock: () => ist(5, 0), locale: 'pa');

      final pa = lookupAppLocalizations(const Locale('pa'));
      expect(pa.youtube_live_semantics, isNot(spoken));
      expect(pa.youtube_live_semantics, contains('YouTube'));
      expect(
        tester.getSemantics(pressable),
        matchesSemantics(
          label: pa.youtube_live_semantics,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('a tap', () {
    testWidgets('opens the exact channel live link, outside the app', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      await pumpRow(tester, clock: () => ist(5, 0));

      await tester.tap(find.text(label));
      await tester.pump();

      expect(launcher.launches, hasLength(1));
      expect(
        launcher.launches.single.url,
        'https://www.youtube.com/channel/UCYn6UEtQ771a_OWSiNBoG8w/live',
      );
      expect(
        launcher.launches.single.mode,
        PreferredLaunchMode.externalApplication,
      );
    });

    testWidgets('stays quiet when the phone cannot open the link', (
      tester,
    ) async {
      final launcher = _FakeLauncher(error: Exception('no app'));
      UrlLauncherPlatform.instance = launcher;
      await pumpRow(tester, clock: () => ist(5, 0));

      await tester.tap(find.text(label));
      await tester.pump();

      expect(launcher.launches, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('with a fresh checked answer', () {
    // 10:30 is between two windows: the timetable alone would hide the row.
    final between = ist(10, 30);
    // 05:00 is inside a window: the timetable alone would show the row.
    final inside = ist(5, 0);

    Future<void> tapLabel(WidgetTester tester) async {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    testWidgets('a kirtan stream shows the row, and a tap opens that video', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      final published = _Published(_file(between, [
        _entry('audio', _audioId),
        _entry('kirtan', _kirtanId),
      ]));
      await pumpRow(tester, clock: () => between, published: published);
      await settle(tester);

      expect(find.text(label), findsOneWidget);
      await tapLabel(tester);

      expect(launcher.launches, hasLength(1));
      expect(launcher.launches.single.url, _watch(_kirtanId));
      expect(
        launcher.launches.single.mode,
        PreferredLaunchMode.externalApplication,
      );
    });

    testWidgets('prefers kirtan to katha, whichever comes first', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      final published = _Published(_file(inside, [
        _entry('katha', _kathaId),
        _entry('kirtan', _kirtanId),
      ]));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      await tapLabel(tester);

      expect(launcher.launches.single.url, _watch(_kirtanId));
    });

    testWidgets('opens the katha stream when there is no kirtan', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      final published = _Published(_file(between, [
        _entry('audio', _audioId),
        _entry('katha', _kathaId),
      ]));
      await pumpRow(tester, clock: () => between, published: published);
      await settle(tester);

      await tapLabel(tester);

      expect(launcher.launches.single.url, _watch(_kathaId));
    });

    testWidgets('opens the channel live page when the stream link is bad', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      final entry = _entry('kirtan', _kirtanId)
        ..['url'] = 'https://evil.example/watch?v=$_kirtanId';
      final published = _Published(_file(between, [entry]));
      await pumpRow(tester, clock: () => between, published: published);
      await settle(tester);

      // A stream is on, so the row stays. Only the link is not trusted.
      expect(find.text(label), findsOneWidget);
      await tapLabel(tester);

      expect(launcher.launches.single.url, kYoutubeLiveUrl);
    });

    testWidgets('audio only hides the row, though a window is open', (
      tester,
    ) async {
      final published = _Published(_file(inside, [_entry('audio', _audioId)]));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      expect(find.text(label), findsNothing);
      expect(tester.getSize(row).height, 0);
    });

    testWidgets('nothing live hides the row, though a window is open', (
      tester,
    ) async {
      final published = _Published(_file(inside, const []));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      expect(find.text(label), findsNothing);
      expect(tester.getSize(row).height, 0);
    });

    testWidgets('a stream of a kind it does not know hides the row', (
      tester,
    ) async {
      final published = _Published(_file(inside, [_entry('shorts', _kathaId)]));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      expect(find.text(label), findsNothing);
    });

    testWidgets('asks the published file once when the row first shows', (
      tester,
    ) async {
      final published =
          _Published(_file(inside, [_entry('kirtan', _kirtanId)]));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      expect(published.calls, 1);
    });
  });

  group('with no fresh checked answer it is the timetable', () {
    final between = ist(10, 30);
    final inside = ist(5, 0);

    Future<void> tapLabel(WidgetTester tester) async {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    testWidgets('a stale answer is ignored: the row opens the channel page', (
      tester,
    ) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      // Empty and 21 minutes old. Fresh, it would hide the row.
      final published = _Published(_file(
        inside,
        const [],
        ago: const Duration(minutes: 21),
      ));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      expect(find.text(label), findsOneWidget);
      await tapLabel(tester);

      expect(launcher.launches.single.url, kYoutubeLiveUrl);
    });

    testWidgets('a stale answer is ignored: outside a window, no row', (
      tester,
    ) async {
      // A kirtan stream, 21 minutes old. Fresh, it would show the row.
      final published = _Published(_file(
        between,
        [_entry('kirtan', _kirtanId)],
        ago: const Duration(minutes: 21),
      ));
      await pumpRow(tester, clock: () => between, published: published);
      await settle(tester);

      expect(find.text(label), findsNothing);
    });

    testWidgets('an answer 20 minutes old still rules', (tester) async {
      final published = _Published(_file(
        inside,
        const [],
        ago: const Duration(minutes: 20),
      ));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      expect(find.text(label), findsNothing);
    });

    testWidgets('an answer 5 minutes ahead of the phone still rules', (
      tester,
    ) async {
      final published = _Published(_file(
        inside,
        const [],
        ago: -const Duration(minutes: 5),
      ));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      expect(find.text(label), findsNothing);
    });

    testWidgets('an answer 6 minutes ahead of the phone is ignored', (
      tester,
    ) async {
      final published = _Published(_file(
        inside,
        const [],
        ago: -const Duration(minutes: 6),
      ));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      expect(find.text(label), findsOneWidget);
    });

    group('when the file cannot be read', () {
      final failures = <String, _Published Function()>{
        'it is not there (404)': _Published.new,
        'the server fails (500)': () => _Published('{}')..status = 500,
        'the phone is offline': () =>
            _Published()..error = http.ClientException('Failed host lookup'),
        'it is not JSON': () => _Published('Service unavailable'),
        'it is JSON of another shape': () => _Published('[1, 2, 3]'),
        'a stream has no link': () => _Published(
              _file(inside, [
                {'kind': 'kirtan', 'videoId': _kirtanId},
              ]),
            ),
      };
      failures.forEach((name, make) {
        testWidgets('$name: inside a window the row opens the channel page', (
          tester,
        ) async {
          final launcher = _FakeLauncher();
          UrlLauncherPlatform.instance = launcher;
          await pumpRow(tester, clock: () => inside, published: make());
          await settle(tester);

          expect(find.text(label), findsOneWidget);
          await tapLabel(tester);

          expect(launcher.launches.single.url, kYoutubeLiveUrl);
          expect(tester.takeException(), isNull);
        });

        testWidgets('$name: outside a window there is no row', (tester) async {
          await pumpRow(tester, clock: () => between, published: make());
          await settle(tester);

          expect(find.text(label), findsNothing);
          expect(tester.takeException(), isNull);
        });
      });
    });

    testWidgets('until the first answer comes, it is the timetable', (
      tester,
    ) async {
      final published = _Published(_file(inside, [_entry('audio', _audioId)]))
        ..gate = Completer<void>();
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      // The request is out. The row is as it was before the check existed.
      expect(published.calls, 1);
      expect(find.text(label), findsOneWidget);

      // The answer says audio only: the row goes.
      published.gate!.complete();
      await tester.pump();
      await settle(tester);

      expect(find.text(label), findsNothing);
    });

    testWidgets('a slow answer that never comes leaves the timetable', (
      tester,
    ) async {
      final published = _Published(_file(inside, const []))
        ..gate = Completer<void>();
      await pumpRow(tester, clock: () => inside, published: published);

      // The service gives up after its time limit. The row never left.
      await tester.pump(const Duration(seconds: 10));
      await settle(tester);

      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('as the file is asked again', () {
    final between = ist(10, 30);
    final inside = ist(5, 0);

    testWidgets('every 5 minutes, and the row follows the new answer', (
      tester,
    ) async {
      final published = _Published(_file(inside, [_entry('audio', _audioId)]));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);
      expect(published.calls, 1);
      expect(find.text(label), findsNothing);

      // The kirtan stream starts. The phone has not asked yet.
      published.body = _file(inside, [_entry('kirtan', _kirtanId)]);
      await tester.pump(const Duration(minutes: 4, seconds: 59));
      expect(published.calls, 1);
      expect(find.text(label), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await settle(tester);
      expect(published.calls, 2);
      expect(find.text(label), findsOneWidget);

      // The stream ends.
      published.body = _file(inside, const []);
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      await settle(tester);
      expect(published.calls, 3);
      expect(find.text(label), findsNothing);
    });

    testWidgets('a failed ask sends the row back to the timetable', (
      tester,
    ) async {
      final published = _Published(_file(inside, const []));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);
      expect(find.text(label), findsNothing);

      published.error = http.ClientException('Failed host lookup');
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      await settle(tester);

      expect(published.calls, 2);
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('keeps the row while the next ask is on its way', (
      tester,
    ) async {
      final published =
          _Published(_file(between, [_entry('kirtan', _kirtanId)]));
      await pumpRow(tester, clock: () => between, published: published);
      await settle(tester);
      expect(find.text(label), findsOneWidget);

      // The next ask is slow. The last answer still rules, so the row does
      // not close for a moment and open again.
      published.gate = Completer<void>();
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      await settle(tester);
      expect(published.calls, 2);
      expect(find.text(label), findsOneWidget);

      published.gate!.complete();
      await tester.pump();
      await settle(tester);
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('does not ask while the app is in the background', (
      tester,
    ) async {
      final published = _Published(_file(inside, [_entry('audio', _audioId)]));
      await pumpRow(tester, clock: () => inside, published: published);
      await settle(tester);

      _leave(tester);
      await tester.pump(const Duration(minutes: 30));

      expect(published.calls, 1);
    });

    testWidgets('an answer goes stale on its own, with no new ask', (
      tester,
    ) async {
      // Made 19 minutes ago: it has 1 minute left to rule.
      var now = between;
      final published = _Published(_file(
        between,
        [_entry('kirtan', _kirtanId)],
        ago: const Duration(minutes: 19),
      ));
      await pumpRow(tester, clock: () => now, published: published);
      await settle(tester);
      expect(find.text(label), findsOneWidget);

      now = between.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      await settle(tester);

      // Only 2 minutes have passed, so the 5-minute ask has not run.
      expect(published.calls, 1);
      expect(find.text(label), findsNothing);
    });

    testWidgets('the answer keeps the row open past a timetable edge', (
      tester,
    ) async {
      var now = ist(9, 4);
      final published = _Published(_file(now, [_entry('kirtan', _kirtanId)]));
      await pumpRow(tester, clock: () => now, published: published);
      await settle(tester);

      // The window closes at 09:05. The stream is still on.
      now = ist(9, 5, 30);
      await tester.pump(const Duration(minutes: 1, seconds: 30));
      await settle(tester);

      expect(published.calls, 1);
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('leaves no timer and no request behind when the row goes', (
      tester,
    ) async {
      final published =
          _Published(_file(inside, [_entry('kirtan', _kirtanId)]));
      await pumpRow(tester, clock: () => inside, published: published);
      await tester.pumpWidget(const SizedBox.shrink());

      // A timer left running would fail the test when it ends.
      await tester.pump(const Duration(days: 1));

      expect(published.calls, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('as the clock moves', () {
    testWidgets('appears by itself when a window opens', (tester) async {
      var now = ist(3, 59, 30);
      await pumpRow(tester, clock: () => now);
      expect(find.text(label), findsNothing);

      // The phone's clock reaches 04:00; the timer set 30 seconds ago fires.
      now = ist(4, 0);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(label), findsOneWidget);
    });

    testWidgets('goes by itself when the window closes', (tester) async {
      var now = ist(9, 4, 0);
      await pumpRow(tester, clock: () => now);
      expect(find.text(label), findsOneWidget);

      now = ist(9, 5);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(label), findsNothing);
    });

    testWidgets('does not change before the edge', (tester) async {
      var now = ist(9, 4, 0);
      await pumpRow(tester, clock: () => now);

      now = ist(9, 4, 30);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(label), findsOneWidget);
    });

    testWidgets('keeps following the windows, edge after edge', (tester) async {
      var now = ist(8, 0);
      await pumpRow(tester, clock: () => now);
      expect(find.text(label), findsOneWidget);

      // Closes at 09:05, opens at 12:30, closes at 14:25.
      for (final (at, shown) in [
        (ist(9, 5), false),
        (ist(12, 30), true),
        (ist(14, 25), false),
      ]) {
        final wait = at.difference(now);
        now = at;
        await tester.pump(wait);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.text(label),
          shown ? findsOneWidget : findsNothing,
          reason: 'at $at',
        );
      }
    });

    testWidgets('leaves no timer behind when the screen goes', (tester) async {
      await pumpRow(tester, clock: () => ist(5, 0));
      await tester.pumpWidget(const SizedBox.shrink());

      // A timer left running would fail the test when it ends.
      await tester.pump(const Duration(days: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('on Home', () {
    testWidgets('sits under live kirtan and above Today', (tester) async {
      await pumpApp(tester, clock: ist(5, 0));

      // The place name is the last line of the live kirtan painting. The mini
      // player has the same words, later in the tree.
      final place = find.text('Sri Harmandir Sahib, Amritsar').first;
      final hero = tester.getTopLeft(place).dy;
      final youtube = tester.getTopLeft(find.text(label)).dy;
      final today = tester.getTopLeft(find.text('TODAY')).dy;
      expect(youtube, greaterThan(hero));
      expect(youtube, lessThan(today));
    });

    testWidgets('is not there outside a window', (tester) async {
      await pumpApp(tester, clock: ist(10, 0));

      expect(find.text(label), findsNothing);
      expect(find.byType(YoutubeLiveRow), findsOneWidget);
    });

    testWidgets('opens the live link from Home', (tester) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      await pumpApp(tester, clock: ist(13, 0));

      await tester.tap(find.text(label));
      await tester.pump();

      expect(launcher.launches.single.url, kYoutubeLiveUrl);
      expect(
        launcher.launches.single.mode,
        PreferredLaunchMode.externalApplication,
      );
    });

    testWidgets('opens the checked video from Home', (tester) async {
      final launcher = _FakeLauncher();
      UrlLauncherPlatform.instance = launcher;
      final at = ist(10, 30);
      final published = _Published(_file(at, [_entry('kirtan', _kirtanId)]));
      await pumpApp(tester, clock: at, youtubeLive: published.service);

      await tester.tap(find.text(label));
      await tester.pump();

      expect(launcher.launches.single.url, _watch(_kirtanId));
    });

    testWidgets('is not there on audio only, though a window is open', (
      tester,
    ) async {
      final at = ist(5, 0);
      final published = _Published(_file(at, [_entry('audio', _audioId)]));
      await pumpApp(tester, clock: at, youtubeLive: published.service);

      expect(find.text(label), findsNothing);
      expect(find.byType(YoutubeLiveRow), findsOneWidget);
    });

    testWidgets('asks the file when the app comes back to the front', (
      tester,
    ) async {
      final at = ist(5, 0);
      final published = _Published(_file(at, [_entry('audio', _audioId)]));
      await pumpApp(tester, clock: at, youtubeLive: published.service);
      expect(published.calls, 1);
      expect(find.text(label), findsNothing);

      // The app goes to the background for an hour. It asks nothing there.
      _leave(tester);
      published.body = _file(at, [_entry('kirtan', _kirtanId)]);
      await tester.pump(const Duration(hours: 1));
      expect(published.calls, 1);

      // Back in front, it asks at once and shows the stream that started.
      _return(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(published.calls, 2);
      expect(find.text(label), findsOneWidget);
    });
  });
}
