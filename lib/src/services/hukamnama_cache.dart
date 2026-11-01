import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:path_provider/path_provider.dart';

/// The last good Hukamnama on disk, one file per SGPC day.
///
/// The file is named for the day the text belongs to
/// (`hukamnama_2026_11_02.json`), so the day is the cache key and an old file
/// can never be mistaken for a new one. [read] also checks the date inside the
/// file against the one asked for, so a renamed or copied file cannot pass
/// either.
///
/// Only the newest day is kept. Yesterday's text is worth having until today's
/// arrives, and after that it is clutter.
///
/// Best effort throughout: a full disk, a corrupt file, or a platform with no
/// application directory (the web build, where `path_provider` has none) is a
/// cache miss and never an error, because the cache only makes things faster
/// and works offline. It must not be able to break the screen it serves.
class HukamnamaCache {
  HukamnamaCache({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  static const _prefix = 'hukamnama_';
  static const _suffix = '.json';

  /// The cached text for exactly [day], or null.
  Future<Hukamnama?> read(DateTime day) async {
    try {
      final dir = await _directory();
      final file = File('${dir.path}/${_nameFor(day)}');
      if (!await file.exists()) return null;
      final cached = await _parse(file);
      final want = DateTime.utc(day.year, day.month, day.day);
      return cached != null && cached.date == want ? cached : null;
    } catch (e) {
      _log('read failed: $e');
      return null;
    }
  }

  /// The newest cached text, whatever day it is for, or null.
  ///
  /// This is for opening on something at once while a fresh copy is fetched.
  /// The caller must check [Hukamnama.date] before calling it today's.
  Future<Hukamnama?> readLatest() async {
    try {
      final dir = await _directory();
      final files = await _cacheFiles(dir);
      // File names sort in date order.
      files.sort((a, b) => b.path.compareTo(a.path));
      for (final file in files) {
        final cached = await _parse(file);
        if (cached != null && file.path.endsWith(_nameFor(cached.date))) {
          return cached;
        }
      }
      return null;
    } catch (e) {
      _log('readLatest failed: $e');
      return null;
    }
  }

  /// Stores [hukamnama] under its own date and drops older days.
  Future<void> write(Hukamnama hukamnama) async {
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      final name = _nameFor(hukamnama.date);

      // Write beside the target and rename, so a crash mid-write leaves the
      // previous file whole instead of half of a new one.
      final temp = File('${dir.path}/$name.tmp');
      await temp.writeAsString(jsonEncode(hukamnama.toJson()), flush: true);
      await temp.rename('${dir.path}/$name');

      // Keep the newest day only, which is not always the one just written.
      final files = await _cacheFiles(dir);
      files.sort((a, b) => b.path.compareTo(a.path));
      for (final stale in files.skip(1)) {
        await stale.delete();
      }
      await _sweepLeftoverTemps(dir);
    } catch (e) {
      _log('write failed: $e');
    }
  }

  /// Deletes `hukamnama_*.json.tmp` files a crash left behind between the
  /// write and the rename.
  ///
  /// A temp file younger than a minute may belong to a write that is still
  /// running, so it is left alone.
  Future<void> _sweepLeftoverTemps(Directory dir) async {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 1));
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith(_prefix) || !name.endsWith('$_suffix.tmp')) continue;
      if ((await entity.lastModified()).isBefore(cutoff)) await entity.delete();
    }
  }

  String _nameFor(DateTime day) => '$_prefix${sgpcDayFileStamp(day)}$_suffix';

  Future<List<File>> _cacheFiles(Directory dir) async {
    if (!await dir.exists()) return [];
    return [
      await for (final entity in dir.list())
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith(_prefix) &&
            entity.path.endsWith(_suffix))
          entity,
    ];
  }

  Future<Hukamnama?> _parse(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return Hukamnama.fromJson(decoded);
    } on FormatException catch (e) {
      _log('${file.path} unreadable: ${e.message}');
      return null;
    }
  }

  void _log(String message) {
    if (!kReleaseMode) debugPrint('[hukamnama cache] $message');
  }
}
