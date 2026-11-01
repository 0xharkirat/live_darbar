import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// The one network the phone is actually using, reduced to what matters here.
enum NetworkKind { none, ethernet, wifi, mobile, other }

/// A comparable picture of the network, so a change can be told from a repeat.
///
/// `connectivity_plus` reports a list of every active interface. The old
/// code collapsed that to online or offline and dropped repeats, which hid a
/// Wi-Fi to mobile handoff completely: online before, online after, nothing
/// emitted. The stream socket is bound to the old interface and dies with it,
/// so the handoff is exactly when playback needs a nudge.
///
/// [kind] is the interface the OS would route through, in its usual order of
/// preference. Ranking them means that a phone holding Wi-Fi and a cellular
/// backup is "wifi", and the backup coming and going changes nothing.
class NetworkSnapshot {
  const NetworkSnapshot(this.kind);

  factory NetworkSnapshot.fromResults(List<ConnectivityResult> results) {
    bool has(ConnectivityResult r) => results.contains(r);
    if (has(ConnectivityResult.ethernet)) {
      return const NetworkSnapshot(NetworkKind.ethernet);
    }
    if (has(ConnectivityResult.wifi)) {
      return const NetworkSnapshot(NetworkKind.wifi);
    }
    if (has(ConnectivityResult.mobile)) {
      return const NetworkSnapshot(NetworkKind.mobile);
    }
    // VPN, Bluetooth tethering and the rest. Online, but not a radio we can
    // name, so a move between these and a named interface counts as a change.
    final anyOther = results.any((r) => r != ConnectivityResult.none);
    return NetworkSnapshot(anyOther ? NetworkKind.other : NetworkKind.none);
  }

  final NetworkKind kind;

  bool get isOnline => kind != NetworkKind.none;

  @override
  bool operator ==(Object other) =>
      other is NetworkSnapshot && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'NetworkSnapshot(${kind.name})';
}

/// What a move between two snapshots means for a stream that is playing.
enum NetworkTransition {
  /// Nothing worth acting on.
  none,

  /// The last interface went away. The stream will fail on its own.
  lost,

  /// An interface came back after none. Reconnect now, do not wait out the
  /// backoff.
  restored,

  /// One interface replaced another with no gap. The stream is dead but the
  /// player may not find out for many seconds.
  handoff,
}

NetworkTransition classifyTransition(
  NetworkSnapshot? previous,
  NetworkSnapshot next,
) {
  // The first reading is a starting point, not an event.
  if (previous == null || previous == next) return NetworkTransition.none;
  if (!next.isOnline) return NetworkTransition.lost;
  if (!previous.isOnline) return NetworkTransition.restored;
  return NetworkTransition.handoff;
}

/// Quiets a stream of readings without hiding an outage or delaying a restore.
///
/// A handoff arrives as a burst, so a move from one online interface to
/// another waits [window] for the readings to settle and then emits the last
/// one. A reading that involves being offline is different. Going offline and
/// coming back online both pass straight through. Debouncing those too, as an
/// earlier version did, swallowed a short outage completely: Wi-Fi, then none,
/// then Wi-Fi inside the window came out as Wi-Fi twice, the second dropped as
/// a repeat, and the stream socket that the outage killed was never reloaded.
/// It also added the window to every restore for nothing.
///
/// [initial] is the reading the listener already holds, so the first repeat of
/// it is not news.
Stream<NetworkSnapshot> settleHandoffs(
  Stream<NetworkSnapshot> readings, {
  required NetworkSnapshot initial,
  Duration window = const Duration(milliseconds: 750),
}) {
  late final StreamController<NetworkSnapshot> out;
  StreamSubscription<NetworkSnapshot>? subscription;
  Timer? settling;
  var last = initial;

  void emit(NetworkSnapshot snapshot) {
    if (snapshot == last) return;
    last = snapshot;
    out.add(snapshot);
  }

  out = StreamController<NetworkSnapshot>(
    onListen: () {
      subscription = readings.listen(
        (reading) {
          // Any new reading supersedes a handoff that was waiting to settle.
          settling?.cancel();
          settling = null;
          if (reading == last) return;
          if (!reading.isOnline || !last.isOnline) {
            emit(reading);
            return;
          }
          settling = Timer(window, () {
            settling = null;
            emit(reading);
          });
        },
        onError: out.addError,
        onDone: () {
          settling?.cancel();
          out.close();
        },
      );
    },
    onCancel: () {
      settling?.cancel();
      return subscription?.cancel();
    },
  );
  return out.stream;
}
