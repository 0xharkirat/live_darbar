import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/review_rules.dart';

/// What counts as a listen, and when the app asks for a rating.
void main() {
  final t0 = DateTime(2026, 11, 6, 6);
  DateTime at(Duration d) => t0.add(d);

  group('ListenTracker', () {
    test('a listen of 10 minutes counts once, at the stop', () {
      final tracker = ListenTracker()..started(t0);
      expect(tracker.stopped(at(const Duration(minutes: 10))), isTrue);
      expect(tracker.meaningful, isTrue);
      // A second stop of the same listen does not count it again.
      tracker.started(at(const Duration(minutes: 10, seconds: 5)));
      expect(tracker.stopped(at(const Duration(minutes: 20))), isFalse);
    });

    test('a short listen does not count', () {
      final tracker = ListenTracker()..started(t0);
      expect(tracker.stopped(at(const Duration(minutes: 9))), isFalse);
      expect(tracker.meaningful, isFalse);
    });

    test('a stall shorter than the gap does not end the listen', () {
      final tracker = ListenTracker()..started(t0);
      expect(tracker.stopped(at(const Duration(minutes: 6))), isFalse);
      tracker.started(at(const Duration(minutes: 6, seconds: 10)));
      expect(
        tracker.stopped(at(const Duration(minutes: 10, seconds: 10))),
        isTrue,
      );
    });

    test('a stop of the gap or longer starts a new listen', () {
      final tracker = ListenTracker()..started(t0);
      tracker.stopped(at(const Duration(minutes: 6)));
      tracker.started(at(const Duration(minutes: 6) + kListenGap));
      expect(tracker.heard, Duration.zero);
      expect(
        tracker.stopped(at(const Duration(minutes: 12) + kListenGap)),
        isFalse,
      );
    });

    test('a stop with no start is ignored', () {
      expect(ListenTracker().stopped(t0), isFalse);
    });
  });

  group('shouldAskForReview', () {
    bool ask({
      int listens = kListensBeforeReview,
      String version = '3.2.0 (12)',
      String? askedVersion,
      bool paused = true,
      bool foreground = true,
    }) =>
        shouldAskForReview(
          ReviewFacts(
            listens: listens,
            version: version,
            askedVersion: askedVersion,
            listenerPaused: paused,
            foreground: foreground,
          ),
        );

    test('asks after enough listens, on a pause, on screen', () {
      expect(ask(), isTrue);
    });

    test('not before enough listens', () {
      expect(ask(listens: kListensBeforeReview - 1), isFalse);
    });

    test('once for each version', () {
      expect(ask(askedVersion: '3.2.0 (12)'), isFalse);
      expect(ask(askedVersion: '3.1.0 (11)'), isTrue);
    });

    test('not in the background, and not without a pause', () {
      expect(ask(foreground: false), isFalse);
      expect(ask(paused: false), isFalse);
    });
  });
}
