import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed version, as the platform bundle reports it.
///
/// This was a constant kept in step with `pubspec.yaml` by hand, which meant
/// the About screen could name a build that was never shipped. Reading the
/// bundle removes the step that gets forgotten. The build number rides along
/// because it is what a bug report actually needs.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});
