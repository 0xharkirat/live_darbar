import 'package:flutter/foundation.dart';

/// A newer release than the one running, and what to say about it.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.build,
    required this.storeUrl,
    required this.notesEn,
    required this.notesPa,
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

  List<String> notesFor(String localeCode) =>
      localeCode == 'pa' && notesPa.isNotEmpty ? notesPa : notesEn;

  /// Reads the manifest, or returns null when this platform has no entry, the
  /// shape is wrong, or there is simply nothing newer.
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

    final stores = json['stores'];
    final storeUrl = stores is Map ? stores[key] : null;
    if (storeUrl is! String || storeUrl.isEmpty) return null;

    final notes = json['notes'];
    return AppUpdate(
      version: version,
      build: build,
      storeUrl: storeUrl,
      notesEn: _notes(notes, 'en'),
      notesPa: _notes(notes, 'pa'),
    );
  }

  static List<String> _notes(Object? notes, String code) {
    if (notes is! Map) return const [];
    final list = notes[code];
    if (list is! List) return const [];
    return list.whereType<String>().toList();
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
