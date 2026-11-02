import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Deletes the Hukamnama PDFs that versions up to 2.2.0 saved.
///
/// Those versions downloaded SGPC's PDF into the documents folder, as
/// `mukhwak_*.pdf`, and kept up to 3 of them. SGPC no longer serves the PDF,
/// and the app now opens SGPC's own page instead, so the files only take
/// space. Nothing else in the app writes that prefix.
///
/// Cheap enough to run on every launch: it lists 1 folder. It never throws.
/// Remove it once 2.2.0 and older are rare in Play Console's version stats.
Future<int> deleteLegacyHukamnamaPdfs({
  Future<Directory> Function() directory = getApplicationDocumentsDirectory,
}) async {
  if (kIsWeb) return 0;
  var deleted = 0;
  try {
    final folder = await directory();
    if (!folder.existsSync()) return 0;
    await for (final entity in folder.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('mukhwak_') || !name.endsWith('.pdf')) continue;
      await entity.delete();
      deleted++;
    }
  } catch (e) {
    if (!kReleaseMode) debugPrint('[cleanup] old Hukamnama PDFs: $e');
  }
  return deleted;
}
