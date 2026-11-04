import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/models/maintenance.dart';

/// The maintenance message in `release.json`, or null when there is none, or
/// when the manifest could not be read. A banner shows it; the app keeps
/// playing what it can.
///
/// It reads the same manifest as the update offer ([releaseManifestProvider]),
/// so the app makes 1 request. The web reads it too: a message about the
/// backend is for every listener, though a reload is the web's update.
final maintenanceProvider = FutureProvider<Maintenance?>((ref) async {
  final manifest = await ref.watch(releaseManifestProvider.future);
  return manifest == null ? null : Maintenance.fromManifest(manifest);
});
