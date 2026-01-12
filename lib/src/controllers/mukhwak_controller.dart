import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class MukhwakController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    return _checkCache();
  }

  Future<String?> _checkCache() async {
    final directory = await getApplicationDocumentsDirectory();
    final today = DateFormat('yyyy_MM_dd').format(DateTime.now());
    final fileName = 'mukhwak_$today.pdf';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);

    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  Future<void> fetchAndCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final today = DateFormat('yyyy_MM_dd').format(DateTime.now());
      final fileName = 'mukhwak_$today.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        state = AsyncValue.data(filePath);
        return;
      }

      state = const AsyncValue.loading();

      final response =
          await http.get(Uri.parse('https://hs.sgpc.net/hukamnamapdf.php'));

      if (response.statusCode == 200) {
        // Clear old cache files
        await _clearOldCache(directory, fileName);

        await file.writeAsBytes(response.bodyBytes);
        state = AsyncValue.data(filePath);
      } else {
        // If fetch fails, we might just keep state as null or error
        // But for now, let's just leave it as is or revert to previous
        state = await AsyncValue.guard(() => Future.value(null));
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _clearOldCache(
      Directory directory, String currentFileName) async {
    try {
      final files = directory.listSync();
      for (var file in files) {
        if (file is File &&
            file.path.endsWith('.pdf') &&
            file.path.contains('mukhwak_') &&
            !file.path.endsWith(currentFileName)) {
          await file.delete();
        }
      }
    } catch (e) {
      // Ignore errors during cleanup
    }
  }
}

final mukhwakController =
    AsyncNotifierProvider<MukhwakController, String?>(MukhwakController.new);
