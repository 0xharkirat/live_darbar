import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/core/display_text.dart';
import 'package:live_darbar/src/core/store_links.dart';

// The update button always opens the fixed store page for the platform,
// from store_links.dart. The manifest never supplies a link: see
// [AppUpdate.fromManifest].

/// A newer release than the one running, and what to say about it.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.build,
    required this.storeUrl,
    required this.notesEn,
    required this.notesPa,
    this.forced = false,
  });

  /// Human-readable, like "2.1.0". Shown to the user.
  final String version;

  /// The number actually compared. Versions are compared by build rather than
  /// by parsing "2.10.0" against "2.9.0", which is a classic way to ship a
  /// comparison bug that only appears at the tenth minor release.
  final int build;

  final String storeUrl;
  final List<String> notesEn;
  final List<String> notesPa;

  /// The installed build is below the least build the manifest accepts
  /// (`minBuild`). The sheet cannot be dismissed and offers only the store,
  /// and a listener who declined this release before is asked again at each
  /// launch.
  final bool forced;

  /// Whether to offer this release, given the newest build the listener has
  /// declined. A forced update is not a courtesy, so a decline does not hide
  /// it.
  bool isOffered({required int dismissedBuild}) =>
      forced || build > dismissedBuild;

  List<String> notesFor(String localeCode) =>
      localeCode == 'pa' && notesPa.isNotEmpty ? notesPa : notesEn;

  /// Reads the manifest, or returns null when this platform has no entry, the
  /// shape is wrong, or there is simply nothing newer.
  ///
  /// The manifest supplies the version, the build and the notes, and nothing
  /// else. Where the button goes is fixed in the app ([kPlayStoreUrl],
  /// [kAppStoreUrl]), whatever the file's `stores` block says. A host check
  /// is not enough: `play.google.com/store/apps/details?id=com.evil.clone`
  /// passes one and still opens somebody else's app, and the manifest is
  /// fetched over the network.
  ///
  /// `web/release.json` keeps its `stores` block anyway. Builds already
  /// installed read it, and refuse the whole manifest without it.
  ///
  /// Every failure here is silent by design. An update prompt is a courtesy,
  /// and a courtesy that shows an error when it cannot reach a JSON file is
  /// worse than one that stays quiet.
  static AppUpdate? fromManifest(
    Map<String, dynamic> json, {
    required int currentBuild,
  }) {
    final key = _platformKey;
    if (key == null) return null;

    final entry = json[key];
    if (entry is! Map) return null;

    final build = entry['build'];
    final version = entry['version'];
    if (build is! int || version is! String) return null;
    if (build <= currentBuild) return null;

    // `minBuild` is optional. Missing, or anything but a whole number from 1
    // to the newest build, means no minimum. A minimum above the newest build
    // would force an update that is not in the store, and lock every listener
    // out, so it is ignored.
    final minBuild = entry['minBuild'];
    final forced = minBuild is int &&
        minBuild > 0 &&
        minBuild <= build &&
        currentBuild < minBuild;

    final notes = json['notes'];
    return AppUpdate(
      version: version,
      build: build,
      storeUrl: _storeUrlFor(key),
      notesEn: _notes(notes, 'en'),
      notesPa: _notes(notes, 'pa'),
      forced: forced,
    );
  }

  /// The newest build the manifest names for this platform, or null when it
  /// names none it can read. [fromManifest] returns null both for "nothing
  /// newer" and for a bad file, and a check the listener asked for must tell
  /// the two apart.
  static int? newestBuild(Map<String, dynamic> json) {
    final key = _platformKey;
    final entry = key == null ? null : json[key];
    if (entry is! Map) return null;
    final build = entry['build'];
    return build is int && entry['version'] is String ? build : null;
  }

  static String _storeUrlFor(String platformKey) =>
      platformKey == 'android' ? kPlayStoreUrl : kAppStoreUrl;

  static List<String> _notes(Object? notes, String code) {
    if (notes is! Map) return const [];
    final list = notes[code];
    if (list is! List) return const [];
    return [
      for (final note in list)
        if (displayText(note) case final text?) text,
    ];
  }

  /// Null on platforms with no store to send anyone to.
  ///
  /// Web is always current by definition: a reload is the update. Linux and
  /// Windows are not shipped.
  ///
  /// Uses [defaultTargetPlatform] rather than `dart:io`'s `Platform`, because
  /// importing `dart:io` at all would break the web build this app also ships.
  static String? get _platformKey {
    if (kIsWeb || kIsWasm) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      _ => null,
    };
  }
}
