// The fixed steps of a Live Darbar release, as commands.
//
// A release has fixed steps (read the version, raise it, check the notes,
// start a build, wait for it, see whether the stores show it) and steps that
// need judgement (what goes in, when to ship, what the notes say). This file
// does the fixed ones, so they come out the same every time. The judgement
// lives in the release skill and with Hark.
//
//   dart tool/release.dart status            version, git, stores, last builds
//   dart tool/release.dart bump patch        raise the version and build number
//   dart tool/release.dart notes             check the store notes
//   dart tool/release.dart build android     start a store release on Codemagic
//   dart tool/release.dart build ios         (both need --confirm, see below)
//   dart tool/release.dart live [--wait]     do the stores show this version?
//
// `build` publishes: the Android workflow sends the bundle to Google Play's
// Production track, and `ios-release` submits to App Store review. So it runs
// only with `--confirm`, which an agent passes only after Hark asks for that
// build in the current conversation.
//
// Codemagic needs CODEMAGIC_TOKEN in the environment. Nothing prints it. The
// store checks need no key: they read the public App Store lookup and the
// public Google Play page.
//
// Plain Dart with no packages, so it runs anywhere the SDK is installed.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The fixed names of this app on Codemagic and in the stores.
abstract final class ReleaseIds {
  static const codemagicApp = '66e3c65fa7f227fc32172736';

  /// The Workflow Editor's "Default Workflow". Each run publishes to Google
  /// Play's Production track. It lives in the editor because the upload
  /// keystore does.
  static const androidWorkflow = '66e3c65fa7f227fc32172735';

  /// In codemagic.yaml. Signs, uploads and submits to App Store review.
  static const iosWorkflow = 'ios-release';

  static const playPackage = 'com.hsi.harki.live_darbar';
  static const appStoreId = '6449766130';
}

// ---------------------------------------------------------------------------
// Pure logic. Tested in test/tool/release_test.dart.
// ---------------------------------------------------------------------------

/// A pubspec version: `3.0.0+10` is name `3.0.0` and build `10`.
class AppVersion {
  const AppVersion(this.name, this.build);

  final String name;
  final int build;

  @override
  String toString() => '$name+$build';

  @override
  bool operator ==(Object other) =>
      other is AppVersion && other.name == name && other.build == build;

  @override
  int get hashCode => Object.hash(name, build);
}

final _versionLine =
    RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)(.*)$', multiLine: true);

/// The version in [pubspec], or null when it has no `version: x.y.z+n` line.
AppVersion? readVersion(String pubspec) {
  final m = _versionLine.firstMatch(pubspec);
  if (m == null) return null;
  return AppVersion('${m[1]}.${m[2]}.${m[3]}', int.parse(m[4]!));
}

/// The next version after [current]: `major`, `minor` or `patch` raises that
/// part and zeroes the ones after it. The build number always goes up by 1,
/// because both stores refuse a build number they have seen.
AppVersion nextVersion(AppVersion current, String part) {
  final p = current.name.split('.').map(int.parse).toList();
  switch (part) {
    case 'major':
      p
        ..[0] += 1
        ..[1] = 0
        ..[2] = 0;
    case 'minor':
      p
        ..[1] += 1
        ..[2] = 0;
    case 'patch':
      p[2] += 1;
    default:
      throw ArgumentError.value(part, 'part', 'use major, minor or patch');
  }
  return AppVersion(p.join('.'), current.build + 1);
}

/// [pubspec] with its version line set to [next], noting the old one as
/// `#prev`, as the file already does.
String writeVersion(String pubspec, AppVersion previous, AppVersion next) {
  if (_versionLine.firstMatch(pubspec) == null) {
    throw const FormatException('pubspec.yaml has no version line.');
  }
  return pubspec.replaceFirst(
    _versionLine,
    'version: $next #prev $previous',
  );
}

/// The App Store allows 4000 characters of What's New.
const kAppStoreNotesMax = 4000;

/// Google Play allows 500 characters of release notes in each language.
const kPlayNotesMax = 500;

/// The problems with the store notes, or none.
///
/// [iosNotes] is ios/whats_new.txt. [playNotesJson] is release_notes.json,
/// which Codemagic reads for Google Play: a list of `{language, text}`. Play
/// has no Punjabi release notes, so every language is an English one.
List<String> checkNotes({
  required String iosNotes,
  required String playNotesJson,
}) {
  final problems = <String>[];
  final ios = iosNotes.trim();
  if (ios.isEmpty) problems.add('ios/whats_new.txt is empty.');
  if (ios.length > kAppStoreNotesMax) {
    problems.add(
      'ios/whats_new.txt has ${ios.length} characters; '
      'the App Store allows $kAppStoreNotesMax.',
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(playNotesJson);
  } on FormatException catch (e) {
    return [...problems, 'release_notes.json is not valid JSON: ${e.message}'];
  }
  if (decoded is! List || decoded.isEmpty) {
    return [...problems, 'release_notes.json must be a non-empty list.'];
  }
  for (final entry in decoded) {
    final language = entry is Map ? entry['language'] : null;
    final text = entry is Map ? entry['text'] : null;
    if (language is! String || text is! String || text.trim().isEmpty) {
      problems.add('release_notes.json has an entry with no language or text.');
      continue;
    }
    if (!language.startsWith('en')) {
      problems.add(
        'release_notes.json has "$language". Google Play has no Punjabi '
        'notes, so keep English only.',
      );
    }
    if (text.length > kPlayNotesMax) {
      problems.add(
        '$language notes have ${text.length} characters; '
        'Google Play allows $kPlayNotesMax.',
      );
    }
  }
  return problems;
}

/// The version that the public Google Play page shows, or null.
///
/// The page carries it as `[[["2.2.0"]]` in its embedded data. This is the
/// version people can install, so it changes only after Google's review.
String? playVersionFromPage(String html) =>
    RegExp(r'\[\[\["(\d+\.\d+\.\d+)"\]\]').firstMatch(html)?[1];

/// The version that the App Store sells, or null when it sells none.
String? appStoreVersionFromLookup(String json) {
  final decoded = jsonDecode(json);
  final results = decoded is Map ? decoded['results'] : null;
  if (results is! List || results.isEmpty) return null;
  final first = results.first;
  return first is Map ? first['version'] as String? : null;
}

/// 1 line per step of a Codemagic build, from the API's build object.
List<String> describeBuild(Map<String, Object?> build) {
  final actions = build['buildActions'];
  return [
    'status: ${build['status']}',
    if (actions is List)
      for (final a in actions)
        if (a is Map) '  ${a['status'] ?? '-'}  ${a['name']}',
  ];
}

// ---------------------------------------------------------------------------
// Commands.
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'help' : args.first;
  final rest = args.skip(1).toList();
  try {
    exitCode = switch (command) {
      'status' => await _status(),
      'bump' => _bump(rest),
      'notes' => _notes(),
      'build' => await _build(rest),
      'live' => await _live(rest),
      _ => _help(),
    };
  } on _Failure catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } finally {
    _http.close();
  }
}

class _Failure implements Exception {
  const _Failure(this.message);
  final String message;
}

int _help() {
  stdout.writeln('Commands: status, bump <major|minor|patch>, notes, '
      'build <android|ios> --confirm, live [--wait]');
  return 2;
}

String _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw const _Failure('Run this inside the live_darbar repo.');
    }
    dir = parent;
  }
  return dir.path;
}

AppVersion _currentVersion() {
  final version =
      readVersion(File('${_repoRoot()}/pubspec.yaml').readAsStringSync());
  if (version == null) {
    throw const _Failure('pubspec.yaml has no version line.');
  }
  return version;
}

Future<int> _status() async {
  final version = _currentVersion();
  stdout.writeln('version  $version');

  final branch = _git(['rev-parse', '--abbrev-ref', 'HEAD']);
  final dirty = _git(['status', '--porcelain']).isNotEmpty;
  _git(['fetch', '--quiet', 'origin']);
  final counts =
      _git(['rev-list', '--left-right', '--count', 'origin/main...HEAD'])
          .split(RegExp(r'\s+'));
  stdout.writeln(
      'git      $branch, ${dirty ? 'uncommitted changes' : 'clean'}, '
      '${counts.length == 2 ? '${counts[1]} ahead and ${counts[0]} behind origin/main' : ''}');

  final stores = await _storeVersions();
  stdout.writeln('play     ${stores.play ?? 'not found'}');
  stdout.writeln('appstore ${stores.appStore ?? 'not on sale'}');

  if (Platform.environment['CODEMAGIC_TOKEN'] == null) {
    stdout.writeln('builds   skipped: CODEMAGIC_TOKEN is not set');
    return 0;
  }
  final list =
      await _codemagic('GET', '/builds?appId=${ReleaseIds.codemagicApp}');
  final builds = (list['builds'] as List? ?? []).cast<Map<String, Object?>>();
  for (final b in builds.take(4)) {
    final workflow = b['fileWorkflowId'] ??
        (b['workflowId'] == ReleaseIds.androidWorkflow
            ? 'android'
            : b['workflowId']);
    final commit = (b['commit'] as Map?)?['hash']?.toString() ?? '';
    stdout.writeln('build    $workflow  ${b['status']}  ${b['branch']}  '
        '${commit.length > 7 ? commit.substring(0, 7) : commit}  ${b['_id']}');
  }
  return 0;
}

int _bump(List<String> args) {
  if (args.isEmpty) {
    throw const _Failure('Say which part: major, minor or patch.');
  }
  final file = File('${_repoRoot()}/pubspec.yaml');
  final text = file.readAsStringSync();
  final current = readVersion(text)!;
  final next = nextVersion(current, args.first);
  file.writeAsStringSync(writeVersion(text, current, next));
  stdout.writeln('$current -> $next');
  return 0;
}

int _notes() {
  final root = _repoRoot();
  final ios = File('$root/ios/whats_new.txt').readAsStringSync();
  final play = File('$root/release_notes.json').readAsStringSync();
  final problems = checkNotes(iosNotes: ios, playNotesJson: play);
  stdout.writeln('App Store (ios/whats_new.txt):\n${ios.trim()}\n');
  final entries = (jsonDecode(play) as List).cast<Map>();
  stdout.writeln('Google Play (release_notes.json, '
      '${entries.map((e) => e['language']).join(', ')}):\n'
      '${entries.first['text']}\n');
  if (problems.isEmpty) {
    stdout.writeln('Notes: OK');
    return 0;
  }
  problems.forEach(stderr.writeln);
  return 1;
}

Future<int> _build(List<String> args) async {
  final platform = args.isEmpty ? '' : args.first;
  final workflow = switch (platform) {
    'android' => ReleaseIds.androidWorkflow,
    'ios' => ReleaseIds.iosWorkflow,
    _ => throw const _Failure('Say which platform: android or ios.'),
  };
  final target =
      platform == 'android' ? 'Google Play Production' : 'App Store review';
  if (!args.contains('--confirm')) {
    stderr.writeln('This builds ${_currentVersion()} from main and sends it to '
        '$target. Builds start only when Hark asks for this one. Run again '
        'with --confirm after he does.');
    return 2;
  }
  final started = await _codemagic('POST', '/builds', {
    'appId': ReleaseIds.codemagicApp,
    'workflowId': workflow,
    'branch': 'main',
  });
  final id = started['buildId'] as String;
  stdout.writeln(
      'started $platform build $id (main, ${_currentVersion()}, to $target)');
  final build = await _waitForBuild(id);
  describeBuild(build).forEach(stdout.writeln);
  return build['status'] == 'finished' ? 0 : 1;
}

Future<int> _live(List<String> args) async {
  final want = _currentVersion().name;
  final wait = args.contains('--wait');
  final deadline = DateTime.now().add(const Duration(days: 4));
  while (true) {
    final stores = await _storeVersions();
    final play = stores.play == want;
    final appStore = stores.appStore == want;
    stdout.writeln('${DateTime.now().toIso8601String().substring(0, 16)}  '
        'want $want  play ${stores.play ?? '-'}${play ? ' LIVE' : ''}  '
        'appstore ${stores.appStore ?? '-'}${appStore ? ' LIVE' : ''}');
    if (play && appStore) return 0;
    if (!wait || DateTime.now().isAfter(deadline)) return 1;
    await Future<void>.delayed(const Duration(minutes: 15));
  }
}

// ---------------------------------------------------------------------------
// I/O.
// ---------------------------------------------------------------------------

final _http = HttpClient()..connectionTimeout = const Duration(seconds: 30);

String _git(List<String> args) {
  final r = Process.runSync('git', args, workingDirectory: _repoRoot());
  return (r.stdout as String).trim();
}

Future<String> _get(Uri uri, {Map<String, String> headers = const {}}) async {
  final request = await _http.getUrl(uri);
  headers.forEach(request.headers.set);
  request.headers.set(
      HttpHeaders.userAgentHeader, 'Mozilla/5.0 (live_darbar release tool)');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode >= 400) {
    throw _Failure(
        'GET ${uri.host}${uri.path} answered ${response.statusCode}.');
  }
  return body;
}

Future<({String? play, String? appStore})> _storeVersions() async {
  String? play;
  String? appStore;
  try {
    play = playVersionFromPage(await _get(Uri.https('play.google.com',
        '/store/apps/details', {'id': ReleaseIds.playPackage, 'hl': 'en'})));
  } on Object {
    play = null;
  }
  try {
    appStore = appStoreVersionFromLookup(await _get(Uri.https(
        'itunes.apple.com', '/lookup', {'id': ReleaseIds.appStoreId})));
  } on Object {
    appStore = null;
  }
  return (play: play, appStore: appStore);
}

Future<Map<String, Object?>> _codemagic(String method, String path,
    [Map<String, Object?>? body]) async {
  final token = Platform.environment['CODEMAGIC_TOKEN'];
  if (token == null || token.isEmpty) {
    throw const _Failure('Set CODEMAGIC_TOKEN first: source ~/.zshrc.local');
  }
  final request =
      await _http.openUrl(method, Uri.parse('https://api.codemagic.io$path'));
  request.headers
    ..set('x-auth-token', token)
    ..contentType = ContentType.json;
  if (body != null) request.write(jsonEncode(body));
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode >= 400) {
    throw _Failure(
        'Codemagic $method $path answered ${response.statusCode}: $text');
  }
  return (jsonDecode(text) as Map).cast<String, Object?>();
}

Future<Map<String, Object?>> _waitForBuild(String id) async {
  const done = {'finished', 'failed', 'canceled', 'timeout', 'skipped'};
  final deadline = DateTime.now().add(const Duration(hours: 2));
  while (true) {
    final build = ((await _codemagic('GET', '/builds/$id'))['build'] as Map)
        .cast<String, Object?>();
    if (done.contains(build['status'])) return build;
    if (DateTime.now().isAfter(deadline)) {
      throw _Failure('Build $id is still ${build['status']} after 2 hours.');
    }
    await Future<void>.delayed(const Duration(seconds: 30));
  }
}
