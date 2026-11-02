import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/services/legacy_pdf_cleanup.dart';

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('pdf_cleanup_'));
  tearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  File touch(String name) =>
      File('${folder.path}/$name')..writeAsStringSync('x');

  test('deletes every PDF the old viewer saved, in all 3 namings', () async {
    touch('mukhwak_day_2026-11-02.pdf');
    touch('mukhwak_latest_2026-11-02.pdf');
    touch('mukhwak_2026-11-01.pdf'); // the oldest naming

    final deleted = await deleteLegacyHukamnamaPdfs(
      directory: () async => folder,
    );

    expect(deleted, 3);
    expect(folder.listSync(), isEmpty);
  });

  test('keeps every other file', () async {
    final kept = [
      touch('hukamnama_cache.json'),
      touch('other.pdf'),
      touch('mukhwak_notes.txt'),
    ];
    Directory('${folder.path}/mukhwak_dir.pdf').createSync();

    final deleted = await deleteLegacyHukamnamaPdfs(
      directory: () async => folder,
    );

    expect(deleted, 0);
    for (final file in kept) {
      expect(file.existsSync(), isTrue, reason: file.path);
    }
    expect(Directory('${folder.path}/mukhwak_dir.pdf').existsSync(), isTrue);
  });

  test('a missing or unreadable folder deletes nothing and does not throw',
      () async {
    folder.deleteSync(recursive: true);
    expect(await deleteLegacyHukamnamaPdfs(directory: () async => folder), 0);
    expect(
      await deleteLegacyHukamnamaPdfs(
        directory: () async => throw const FileSystemException('denied'),
      ),
      0,
    );
  });
}
