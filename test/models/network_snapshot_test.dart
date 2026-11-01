import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/network_snapshot.dart';

void main() {
  NetworkSnapshot snap(List<ConnectivityResult> results) =>
      NetworkSnapshot.fromResults(results);

  final wifi = snap([ConnectivityResult.wifi]);
  final mobile = snap([ConnectivityResult.mobile]);
  final none = snap([ConnectivityResult.none]);

  group('NetworkSnapshot.fromResults', () {
    test('an empty list and a lone none both mean offline', () {
      expect(snap([]).kind, NetworkKind.none);
      expect(none.kind, NetworkKind.none);
      expect(none.isOnline, isFalse);
    });

    test('names the interface', () {
      expect(wifi.kind, NetworkKind.wifi);
      expect(mobile.kind, NetworkKind.mobile);
      expect(snap([ConnectivityResult.ethernet]).kind, NetworkKind.ethernet);
      expect(wifi.isOnline, isTrue);
    });

    test('ranks ethernet above wifi above mobile', () {
      expect(
        snap([ConnectivityResult.mobile, ConnectivityResult.wifi]).kind,
        NetworkKind.wifi,
      );
      expect(
        snap([ConnectivityResult.wifi, ConnectivityResult.ethernet]).kind,
        NetworkKind.ethernet,
      );
    });

    test('a VPN over wifi is still wifi', () {
      expect(
        snap([ConnectivityResult.wifi, ConnectivityResult.vpn]).kind,
        NetworkKind.wifi,
      );
    });

    test('a lone VPN or Bluetooth link is online but unnamed', () {
      expect(snap([ConnectivityResult.vpn]).kind, NetworkKind.other);
      expect(snap([ConnectivityResult.bluetooth]).kind, NetworkKind.other);
    });

    test('compares by value', () {
      expect(wifi, snap([ConnectivityResult.wifi, ConnectivityResult.vpn]));
      expect(wifi, isNot(mobile));
    });
  });

  group('settleHandoffs', () {
    // Real timers with a short window: flutter_test does not export fake_async.
    const window = Duration(milliseconds: 60);
    const pause = Duration(milliseconds: 150);

    late StreamController<NetworkSnapshot> readings;
    late List<NetworkSnapshot> seen;

    setUp(() {
      readings = StreamController<NetworkSnapshot>();
      seen = [];
    });

    tearDown(() => readings.close());

    StreamSubscription<NetworkSnapshot> settle(NetworkSnapshot initial) {
      return settleHandoffs(readings.stream, initial: initial, window: window)
          .listen(seen.add);
    }

    Future<void> tick() => Future<void>.delayed(Duration.zero);

    test('passes going offline through at once', () async {
      final sub = settle(wifi);
      addTearDown(sub.cancel);

      readings.add(none);
      await tick();

      expect(seen, [none]);
    });

    test('passes coming back online through at once', () async {
      final sub = settle(none);
      addTearDown(sub.cancel);

      readings.add(mobile);
      await tick();

      expect(seen, [mobile]);
    });

    test('a short outage still reads as lost, then restored', () async {
      final sub = settle(wifi);
      addTearDown(sub.cancel);

      // Wi-Fi, none, Wi-Fi inside one window. The debounced version emitted
      // nothing here, because the last reading equalled the first.
      readings.add(none);
      readings.add(wifi);
      await tick();

      expect(seen, [none, wifi]);
      expect(classifyTransition(wifi, seen[0]), NetworkTransition.lost);
      expect(classifyTransition(seen[0], seen[1]), NetworkTransition.restored);
    });

    test('holds a handoff until the readings settle', () async {
      final sub = settle(wifi);
      addTearDown(sub.cancel);

      readings.add(mobile);
      await tick();
      expect(seen, isEmpty);

      await Future<void>.delayed(pause);
      expect(seen, [mobile]);
    });

    test('a burst of handoff readings emits the last one once', () async {
      final sub = settle(wifi);
      addTearDown(sub.cancel);

      readings.add(mobile);
      readings.add(snap([ConnectivityResult.ethernet]));
      readings.add(mobile);
      await Future<void>.delayed(pause);

      expect(seen, [mobile]);
    });

    test('a handoff that flips back before it settles emits nothing', () async {
      final sub = settle(wifi);
      addTearDown(sub.cancel);

      readings.add(mobile);
      readings.add(wifi);
      await Future<void>.delayed(pause);

      expect(seen, isEmpty);
    });

    test('an outage during a pending handoff cancels the handoff', () async {
      final sub = settle(wifi);
      addTearDown(sub.cancel);

      readings.add(mobile);
      readings.add(none);
      await Future<void>.delayed(pause);

      expect(seen, [none]);
    });

    test('drops a repeat of the reading it already holds', () async {
      final sub = settle(wifi);
      addTearDown(sub.cancel);

      readings.add(snap([ConnectivityResult.wifi, ConnectivityResult.vpn]));
      await Future<void>.delayed(pause);

      expect(seen, isEmpty);
    });

    test('closes when the readings close', () async {
      final done = Completer<void>();
      settleHandoffs(readings.stream, initial: wifi, window: window)
          .listen(seen.add, onDone: done.complete);

      readings.add(mobile);
      await readings.close();

      await done.future.timeout(const Duration(seconds: 2));
    });
  });

  group('classifyTransition', () {
    test('the first reading is not an event', () {
      expect(classifyTransition(null, wifi), NetworkTransition.none);
      expect(classifyTransition(null, none), NetworkTransition.none);
    });

    test('a repeat is not an event', () {
      expect(classifyTransition(wifi, wifi), NetworkTransition.none);
      expect(classifyTransition(none, none), NetworkTransition.none);
    });

    test('wifi to mobile is a handoff', () {
      expect(classifyTransition(wifi, mobile), NetworkTransition.handoff);
    });

    test('mobile to wifi is a handoff', () {
      expect(classifyTransition(mobile, wifi), NetworkTransition.handoff);
    });

    test('losing the only interface is a loss', () {
      expect(classifyTransition(wifi, none), NetworkTransition.lost);
    });

    test('regaining an interface is a restore, on either radio', () {
      expect(classifyTransition(none, wifi), NetworkTransition.restored);
      expect(classifyTransition(none, mobile), NetworkTransition.restored);
    });

    test('a cellular backup joining wifi is not a handoff', () {
      final both = snap([ConnectivityResult.wifi, ConnectivityResult.mobile]);
      expect(classifyTransition(wifi, both), NetworkTransition.none);
      expect(classifyTransition(both, wifi), NetworkTransition.none);
    });

    test('wifi dropping to its mobile backup is a handoff', () {
      final both = snap([ConnectivityResult.wifi, ConnectivityResult.mobile]);
      expect(classifyTransition(both, mobile), NetworkTransition.handoff);
    });
  });
}
