// Builds the whole darbar.live site into one folder, build/site/.
//
//     taskpolicy -b dart tool/build_site.dart
//     dart tool/build_site.dart --skip-flutter   # reuse an earlier build/web
//
// What lands in build/site/ (firebase.json serves that folder):
//
//     /               site/              the landing page, plain HTML and CSS.
//                                        Its {{version}} is filled in here:
//                                        the newest version in
//                                        web/release.json.
//     /app/           build/web/         the Flutter web app, built with
//                                        --base-href /app/
//     /release.json   web/release.json   what installed apps read to find out
//                                        about updates. Kept at the root.
//
// Then deploy with `firebase deploy --only hosting`. This script deploys
// nothing.
import 'dart:convert';
import 'dart:io';

const _baseHref = '/app/';

Future<void> main(List<String> args) async {
  final skipFlutter = args.contains('--skip-flutter');
  final root = File(Platform.script.toFilePath()).parent.parent.path;
  final site = Directory(_join(root, 'site'));
  final web = Directory(_join(root, 'build', 'web'));
  final out = Directory(_join(root, 'build', 'site'));
  final release = File(_join(root, 'web', 'release.json'));

  if (!site.existsSync()) _fail('Missing ${site.path}.');
  if (!release.existsSync()) _fail('Missing ${release.path}.');
  _checkRelease(release);

  // Both of these would be overwritten by the assembly below.
  for (final name in ['app', 'release.json']) {
    final path = _join(site.path, name);
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound) {
      _fail('site/$name collides with the file the build puts there.');
    }
  }

  if (!skipFlutter) {
    stdout.writeln('flutter build web --base-href $_baseHref');
    final build = await Process.start(
      'flutter',
      ['build', 'web', '--release', '--base-href', _baseHref],
      workingDirectory: root,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await build.exitCode;
    if (code != 0) _fail('flutter build web failed with exit code $code.');
  }

  final shell = File(_join(web.path, 'index.html'));
  if (!shell.existsSync()) {
    _fail('No ${shell.path}. Run without --skip-flutter first.');
  }
  // A leftover build made for the root would load nothing from /app/.
  if (!shell.readAsStringSync().contains('<base href="$_baseHref">')) {
    _fail(
      'build/web was not built with --base-href $_baseHref. '
      'Run without --skip-flutter.',
    );
  }

  if (out.existsSync()) out.deleteSync(recursive: true);
  out.createSync(recursive: true);

  _copy(site, out);
  _fillRelease(out, release);
  // web/release.json is copied into build/web by Flutter. The root copy below
  // is the one apps read, so the app folder does not carry a second one.
  _copy(web, Directory(_join(out.path, 'app')), skip: {'release.json'});
  release.copySync(_join(out.path, 'release.json'));

  for (final path in [
    'index.html',
    'pa/index.html',
    'app/index.html',
    'release.json',
  ]) {
    if (!File(_join(out.path, path)).existsSync()) _fail('Missing $path.');
  }

  stdout
    ..writeln('')
    ..writeln('Built ${out.path}')
    ..writeln('  landing page   ${_kb(_size(site))} (site/)')
    ..writeln(
        '  web app        ${_kb(_size(Directory(_join(out.path, 'app'))))} (/app/)')
    ..writeln('Serve it, for example: cd build/site && python3 -m http.server');
}

/// Copies [from] into [to], without dotfiles such as .DS_Store.
void _copy(Directory from, Directory to, {Set<String> skip = const {}}) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(followLinks: false)) {
    final name = _name(entity);
    if (name.startsWith('.')) continue;
    if (entity is Directory) {
      _copy(entity, Directory(_join(to.path, name)));
    } else if (entity is File && !skip.contains(name)) {
      entity.copySync(_join(to.path, name));
    }
  }
}

/// Fills the page's `{{version}}`, so the line under the buttons cannot drift
/// from the app.
void _fillRelease(Directory out, File release) {
  final json = jsonDecode(release.readAsStringSync()) as Map<String, dynamic>;
  // The newest build is the one the stores offer first. Android and iOS can
  // differ for a few days when one store is ahead of the other.
  final newest = ['android', 'ios']
      .map((k) => json[k] as Map<String, dynamic>)
      .reduce((a, b) => (a['build'] as int) >= (b['build'] as int) ? a : b);
  final version = newest['version'] as String;
  stdout.writeln('  release line   Version $version');

  for (final path in ['index.html', 'pa/index.html']) {
    final file = File(_join(out.path, path));
    final text = file.readAsStringSync().replaceAll('{{version}}', version);
    if (text.contains('{{')) _fail('$path has a {{token}} the build does not fill.');
    file.writeAsStringSync(text);
  }
}

/// Installed apps read this file. Stop before a broken one ships.
void _checkRelease(File file) {
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final key in ['android', 'ios', 'macos', 'stores', 'notes']) {
      if (json[key] == null) _fail('web/release.json has no "$key".');
    }
  } on FormatException catch (e) {
    _fail('web/release.json is not valid JSON: ${e.message}');
  }
}

int _size(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .fold(0, (sum, file) => sum + file.lengthSync());

String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';

/// The last segment of a path, with no separator.
String _name(FileSystemEntity entity) =>
    entity.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);

String _join(String a, [String? b, String? c]) =>
    [a, if (b != null) b, if (c != null) c].join(Platform.pathSeparator);

Never _fail(String message) {
  stderr.writeln('build_site: $message');
  exit(1);
}
