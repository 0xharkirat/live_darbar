import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has a network interface at all.
///
/// Read this narrowly. `connectivity_plus` reports what the operating system
/// is attached to, not whether packets reach the internet, so it says
/// connected on a captive portal in a hotel or an airport, and on a wifi
/// network whose uplink is down. It answers "is the radio off" reliably and
/// nothing more.
///
/// That is still worth having, because it is the only signal available before
/// the app tries anything. Without it, someone who opens the app in aeroplane
/// mode sees a warm-up fail silently and no explanation until they press play.
///
/// The other half of the picture comes from the audio layer, which knows when
/// requests genuinely fail. Together they separate two situations that deserve
/// different words: the phone is offline, or the phone is online and the
/// stream is unreachable.
class ConnectivityController extends StreamNotifier<bool> {
  @override
  Stream<bool> build() async* {
    final connectivity = Connectivity();

    // Seed from the current state so the first frame is not a guess.
    yield _isOnline(await connectivity.checkConnectivity());

    yield* connectivity.onConnectivityChanged.map(_isOnline).distinct();
  }

  static bool _isOnline(List<ConnectivityResult> results) {
    // An empty list and a list containing only `none` both mean no interface.
    return results.any((r) => r != ConnectivityResult.none);
  }
}

final connectivityController =
    StreamNotifierProvider<ConnectivityController, bool>(
  ConnectivityController.new,
);
