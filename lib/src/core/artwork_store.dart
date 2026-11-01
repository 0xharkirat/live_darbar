import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Puts the bundled paintings where the lock screen and the car can read them.
///
/// `MediaItem.artUri` cannot name a Flutter asset. The notification, the lock
/// screen and a Bluetooth display are all outside the Flutter engine, and an
/// asset is not a file. So each painting is copied once into the app's support
/// directory and handed over as a `file:` URI. This replaces a GitHub URL that
/// every device fetched over the network, from a branch that could move.
///
/// Web has no file system and `just_audio_background` is not started there, so
/// [prepare] returns nothing on web and the tags go without artwork.
class ArtworkStore {
  ArtworkStore({
    Future<Directory> Function()? supportDirectory,
    Future<ByteData> Function(String asset)? loadAsset,
    bool? isWeb,
  })  : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        _loadAsset = loadAsset ?? rootBundle.load,
        _isWeb = isWeb ?? (kIsWeb || kIsWasm);

  /// The painting for each source index: live, Mukhwak, Katha. These are the
  /// same images the home screen draws behind each tile.
  static const assets = <int, String>{
    0: 'assets/images/0.jpg',
    1: 'assets/images/1.jpg',
    2: 'assets/images/2.jpg',
  };

  final Future<Directory> Function() _supportDirectory;
  final Future<ByteData> Function(String asset) _loadAsset;
  final bool _isWeb;

  Future<Map<int, Uri>>? _prepared;

  /// Copies any missing painting, once, and returns the URI for each source
  /// that has one. Never throws: no artwork beats no audio.
  Future<Map<int, Uri>> prepare() => _prepared ??= _prepare();

  Future<Map<int, Uri>> _prepare() async {
    if (_isWeb) return const {};
    final found = <int, Uri>{};
    try {
      final base = await _supportDirectory();
      final dir = Directory('${base.path}/artwork');
      await dir.create(recursive: true);
      for (final entry in assets.entries) {
        try {
          final file = File('${dir.path}/${entry.key}.jpg');
          await _ensureCopied(entry.value, file);
          found[entry.key] = file.uri;
        } catch (e) {
          if (!kReleaseMode) debugPrint('[artwork] ${entry.value}: $e');
        }
      }
    } catch (e) {
      if (!kReleaseMode) debugPrint('[artwork] unavailable: $e');
    }
    return found;
  }

  /// Copies [asset] to [file] unless a file of the same size is there already.
  ///
  /// Size is a cheap stand-in for "same painting". An app update that swaps an
  /// image almost always changes its length, and checking it costs one stat.
  /// The copy goes through a temporary name, so the media session can never
  /// open a half-written image.
  Future<void> _ensureCopied(String asset, File file) async {
    final data = await _loadAsset(asset);
    if (await file.exists() && await file.length() == data.lengthInBytes) {
      return;
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await temp.rename(file.path);
  }
}
