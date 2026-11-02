import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Puts the bundled paintings where the lock screen and the car can read them.
///
/// `MediaItem.artUri` cannot name a Flutter asset. The notification, the lock
/// screen and a Bluetooth display are all outside the Flutter engine, and an
/// asset is not a file. So each painting is copied once into the app's support
/// directory. This replaces a GitHub URL that every device fetched over the
/// network, from a branch that could move.
///
/// What [prepare] hands back depends on who reads it. On iOS it is a `file:`
/// URI to the copy. On Android a `file:` URI into the app's private directory
/// is unreadable to the Android Auto host, so the URI names `ArtworkProvider`
/// instead, a read-only `content:` provider that serves those same three
/// copies. The two sides share the directory name, the file names and the
/// authority below.
///
/// Web has no file system and the media session is not started there, so
/// [prepare] returns nothing on web and the tags go without artwork.
class ArtworkStore {
  ArtworkStore({
    Future<Directory> Function()? supportDirectory,
    Future<ByteData> Function(String asset)? loadAsset,
    bool? isWeb,
    bool? isAndroid,
  })  : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        _loadAsset = loadAsset ?? rootBundle.load,
        _isWeb = isWeb ?? (kIsWeb || kIsWasm),
        _isAndroid = isAndroid ??
            (!(kIsWeb || kIsWasm) &&
                defaultTargetPlatform == TargetPlatform.android);

  /// The painting for each source index: live, Mukhwak, Katha. These are the
  /// same images the home screen draws behind each tile.
  static const assets = <int, String>{
    0: 'assets/images/0.jpg',
    1: 'assets/images/1.jpg',
    2: 'assets/images/2.jpg',
  };

  /// The authority of `ArtworkProvider`: the application id plus `.artwork`.
  /// The manifest builds the same string from `${applicationId}`.
  static const providerAuthority = 'com.hsi.harki.live_darbar.artwork';

  /// The folder in the support directory that holds the copies. The provider
  /// reads `files/artwork`, and the support directory is `files` on Android.
  static const directoryName = 'artwork';

  /// The URI that serves source [index] on Android: the provider's authority
  /// and the file name, which is all the provider looks at.
  static Uri contentUriFor(int index) => Uri(
        scheme: 'content',
        host: providerAuthority,
        path: '/$index.jpg',
      );

  final Future<Directory> Function() _supportDirectory;
  final Future<ByteData> Function(String asset) _loadAsset;
  final bool _isWeb;
  final bool _isAndroid;

  Future<Map<int, Uri>>? _prepared;

  /// Copies any missing painting, once, and returns the URI for each source
  /// that has one: a `content:` URI on Android, a `file:` URI elsewhere. A
  /// painting that failed to copy has no URI, because the provider would have
  /// nothing to serve. Never throws: no artwork beats no audio.
  Future<Map<int, Uri>> prepare() => _prepared ??= _prepare();

  Future<Map<int, Uri>> _prepare() async {
    if (_isWeb) return const {};
    final found = <int, Uri>{};
    try {
      final base = await _supportDirectory();
      final dir = Directory('${base.path}/$directoryName');
      await dir.create(recursive: true);
      for (final entry in assets.entries) {
        try {
          final file = File('${dir.path}/${entry.key}.jpg');
          await _ensureCopied(entry.value, file);
          found[entry.key] = _isAndroid ? contentUriFor(entry.key) : file.uri;
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
