import 'package:permission_handler/permission_handler.dart';

class PermissionHandler {
  /// Request the files permission and updates the UI accordingly
  static Future<bool> checkStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      return true;
    } else {
      if (await Permission.storage.request().isPermanentlyDenied) {
        await openAppSettings();
      } else {
        await Permission.storage.request();
      }
      return await Permission.storage.request().isGranted;
    }
  }
}
