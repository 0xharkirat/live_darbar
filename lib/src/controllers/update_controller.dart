import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:live_darbar/src/models/app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the released version numbers live.
///
/// Served by Firebase Hosting from the same project as darbar.live. Firebase
/// serves real files before applying the catch-all rewrite in firebase.json,
/// so this returns JSON rather than index.html. The file is `web/release.json`
/// in this repo and ships with the web build.
///
/// Deliberately not `version.json`. Flutter's web build emits a file by that
/// exact name for PWA versioning, shaped `{app_name, version, build_number,
/// package_name}` with the build number as a string. It would overwrite ours
/// on every deploy, the parser would reject the replacement, and the app would
/// silently stop ever offering an update. That one is live at
/// darbar.live/version.json right now, still advertising 2.0.1+5.
/// Overridable so the sheet can be exercised against a manifest that actually
/// advertises a newer build:
///
///   flutter run --dart-define=RELEASE_MANIFEST_URL=http://10.0.2.2:8000/release.json
///
/// 10.0.2.2 is the host machine as seen from the Android emulator. Testing
/// that way also needs the emulator loopback permitted in
/// network_security_config.xml, which it is not by default and should not be.
const kReleaseManifestUrl = String.fromEnvironment(
  'RELEASE_MANIFEST_URL',
  defaultValue: 'https://darbar.live/release.json',
);

/// Checks whether a newer release exists, once per launch.
///
/// Deliberately not the Play In-App Update API, at least not yet. That API is
/// the better Android experience, because it downloads inside the app instead
/// of sending someone to the Play page, and it is worth adding later behind
/// this same controller. It is not the right first step: it is Android only,
/// so iOS and macOS would still need this path; it cannot be tested without
/// internal app sharing, so it would ship unverified; it pulls in Play Core,
/// against the goal of keeping the app small; and it offers no release notes,
/// which is most of what makes the prompt worth showing at all.
///
/// Everything here fails quietly. An update prompt is a courtesy, and a
/// courtesy that shows an error because it could not reach a JSON file is
/// worse than one that says nothing.
class UpdateController extends AsyncNotifier<AppUpdate?> {
  static const _dismissedBuildKey = 'update_dismissed_build';
  static const _timeout = Duration(seconds: 8);

  @override
  Future<AppUpdate?> build() async {
    try {
      return await _check();
    } catch (e) {
      if (!kReleaseMode) debugPrint('[update] check failed: $e');
      return null;
    }
  }

  Future<AppUpdate?> _check() async {
    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber);
    // Without a build number there is nothing safe to compare, so say nothing
    // rather than guess by parsing version strings.
    if (currentBuild == null) return null;

    final response = await http
        .get(Uri.parse(kReleaseManifestUrl))
        .timeout(_timeout);
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final update = AppUpdate.fromManifest(decoded, currentBuild: currentBuild);
    if (update == null) return null;

    // Asking once per release is a reminder. Asking every launch is nagging,
    // and this audience is the least likely to enjoy being nagged. A newer
    // build than the dismissed one is a new question and gets asked again.
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getInt(_dismissedBuildKey) ?? 0;
    if (update.build <= dismissed) return null;

    return update;
  }

  /// Remember that this release was declined, and stop offering it.
  Future<void> dismiss() async {
    final update = state.value;
    state = const AsyncValue.data(null);
    if (update == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dismissedBuildKey, update.build);
  }
}

final updateController =
    AsyncNotifierProvider<UpdateController, AppUpdate?>(UpdateController.new);
