import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/whats_new_rules.dart';
import 'package:live_darbar/src/models/whats_new.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the notes of a release live. One file for each release, named for it,
/// so the next release adds a file and no code. The whole folder is declared
/// in `pubspec.yaml`.
String whatsNewAsset(String release) => 'assets/whats_new/$release.json';

/// The notes of [release] in [bundle], or null when the release has no file or
/// the file is not usable. It asks the asset manifest first, so a release with
/// no notes makes no failed request on the web.
Future<WhatsNew?> loadWhatsNew(AssetBundle bundle, String release) async {
  final path = whatsNewAsset(release);
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    if (!manifest.listAssets().contains(path)) return null;
    final notes = WhatsNew.fromJson(jsonDecode(await bundle.loadString(path)));
    return notes?.release == release ? notes : null;
  } catch (_) {
    // A courtesy, like the update offer: it stays quiet when it cannot read.
    return null;
  }
}

/// Reads the notes of a release. A test gives its own.
final whatsNewLoaderProvider =
    Provider<Future<WhatsNew?> Function(String release)>(
  (ref) => (release) => loadWhatsNew(rootBundle, release),
);

/// The installed release, such as `3.1`. Null when the platform gives no
/// version.
final releaseProvider = FutureProvider<String?>((ref) async {
  return releaseOf(await ref.watch(appVersionProvider.future));
});

/// How long Home must be calm, on top and at rest, before the notes appear.
final whatsNewSettleProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 1200),
);

/// The notes to show on this launch, or null.
///
/// The first read decides (see [decideWhatsNew]): a fresh install records the
/// release and shows nothing, a release with no notes does the same, and the
/// first open after an update returns its notes. The release is marked seen
/// when the sheet appears ([markSeen]), so the notes show once even if the
/// listener swipes them away, and never again for that release.
class WhatsNewController extends AsyncNotifier<WhatsNew?> {
  static const seenKey = 'whats_new_seen_release';

  @override
  Future<WhatsNew?> build() async {
    final release = await ref.watch(releaseProvider.future);
    if (release == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getString(seenKey);
    final notes = seen == release
        ? null
        : await ref.read(whatsNewLoaderProvider)(release);

    final action = decideWhatsNew(
      seen: seen,
      release: release,
      hasNotes: notes != null,
      existingInstall: prefs.getKeys().any((key) => key != seenKey),
    );
    switch (action) {
      case WhatsNewAction.nothing:
        return null;
      case WhatsNewAction.record:
        await prefs.setString(seenKey, release);
        return null;
      case WhatsNewAction.show:
        return notes;
    }
  }

  /// The notes are on screen. Never show this release again.
  Future<void> markSeen() async {
    final notes = state.value;
    if (notes == null) return;
    state = const AsyncValue.data(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(seenKey, notes.release);
  }
}

final whatsNewController =
    AsyncNotifierProvider<WhatsNewController, WhatsNew?>(
  WhatsNewController.new,
);
