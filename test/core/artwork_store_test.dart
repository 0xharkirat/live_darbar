import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/artwork_store.dart';

void main() {
  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('artwork_store_test');
  });

  tearDown(() {
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  ByteData bytesOf(String text) =>
      ByteData.sublistView(Uint8List.fromList(text.codeUnits));

  ArtworkStore store({
    Map<String, String>? contents,
    bool isWeb = false,
    List<String>? loads,
  }) {
    final data = contents ??
        {
          for (final asset in ArtworkStore.assets.values) asset: 'art:$asset',
        };
    return ArtworkStore(
      supportDirectory: () async => support,
      loadAsset: (asset) async {
        loads?.add(asset);
        final text = data[asset];
        if (text == null) throw StateError('missing asset $asset');
        return bytesOf(text);
      },
      isWeb: isWeb,
    );
  }

  test('copies each painting and returns a file URI for it', () async {
    final uris = await store().prepare();

    expect(uris.keys, ArtworkStore.assets.keys);
    for (final entry in uris.entries) {
      expect(entry.value.scheme, 'file');
      final file = File.fromUri(entry.value);
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), 'art:${ArtworkStore.assets[entry.key]}');
    }
  });

  test('keeps the files under the support directory', () async {
    final uris = await store().prepare();
    for (final uri in uris.values) {
      expect(uri.toFilePath(), startsWith(support.path));
    }
  });

  test('does not rewrite a file that is already current', () async {
    await store().prepare();
    final file = File('${support.path}/artwork/0.jpg');
    final before = file.statSync().modified;
    // Make a rewrite visible: any new write would move this timestamp.
    file.setLastModifiedSync(before.subtract(const Duration(days: 1)));
    final marked = file.statSync().modified;

    await store().prepare();

    expect(file.statSync().modified, marked);
  });

  test('replaces a file whose size no longer matches the asset', () async {
    await store().prepare();
    final file = File('${support.path}/artwork/1.jpg');
    file.writeAsStringSync('stale');

    await store().prepare();

    expect(file.readAsStringSync(), 'art:assets/images/1.jpg');
  });

  test('leaves no temporary file behind', () async {
    await store().prepare();
    final names = Directory('${support.path}/artwork')
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .toList()
      ..sort();
    expect(names, ['0.jpg', '1.jpg', '2.jpg']);
  });

  test('prepares once, however many callers ask', () async {
    final loads = <String>[];
    final s = store(loads: loads);

    final results = await Future.wait([s.prepare(), s.prepare(), s.prepare()]);
    await s.prepare();

    expect(loads, hasLength(ArtworkStore.assets.length));
    expect(results.first, results.last);
  });

  test('a missing asset costs only that painting', () async {
    final contents = {
      'assets/images/0.jpg': 'zero',
      'assets/images/2.jpg': 'two',
    };

    final uris = await store(contents: contents).prepare();

    expect(uris.keys, unorderedEquals([0, 2]));
  });

  test('returns nothing instead of throwing when storage fails', () async {
    final broken = ArtworkStore(
      supportDirectory: () async => throw const FileSystemException('no disk'),
      loadAsset: (asset) async => bytesOf('x'),
      isWeb: false,
    );

    expect(await broken.prepare(), isEmpty);
  });

  test('web gets no file URIs and touches no files', () async {
    final loads = <String>[];

    final uris = await store(isWeb: true, loads: loads).prepare();

    expect(uris, isEmpty);
    expect(loads, isEmpty);
    expect(Directory('${support.path}/artwork').existsSync(), isFalse);
  });
}
