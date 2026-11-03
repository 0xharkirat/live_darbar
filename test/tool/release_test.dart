import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release.dart';

void main() {
  group('the version', () {
    test('reads the pubspec line, comment and all', () {
      expect(
        readVersion('name: x\nversion: 3.0.0+10 #prev 2.2.0+8\n'),
        const AppVersion('3.0.0', 10),
      );
    });

    test('reads the real pubspec', () {
      expect(readVersion(File('pubspec.yaml').readAsStringSync()), isNotNull);
    });

    test('is null with no version line', () {
      expect(readVersion('name: x\n'), isNull);
    });

    test('goes up by part, and the build number always goes up by 1', () {
      const v = AppVersion('3.0.0', 10);
      expect(nextVersion(v, 'patch'), const AppVersion('3.0.1', 11));
      expect(nextVersion(v, 'minor'), const AppVersion('3.1.0', 11));
      expect(nextVersion(const AppVersion('3.4.5', 20), 'major'),
          const AppVersion('4.0.0', 21));
      expect(() => nextVersion(v, 'huge'), throwsArgumentError);
    });

    test('is written back with the old one as #prev', () {
      const old = AppVersion('3.0.0', 10);
      final next = nextVersion(old, 'patch');
      final out = writeVersion(
        'name: x\nversion: 3.0.0+10 #prev 2.2.0+8\ndescription: y\n',
        old,
        next,
      );
      expect(
          out, 'name: x\nversion: 3.0.1+11 #prev 3.0.0+10\ndescription: y\n');
      expect(readVersion(out), next);
    });
  });

  group('the store notes', () {
    String play(List<Map<String, String>> entries) => jsonEncode(entries);

    test('pass when both are present, short and English', () {
      expect(
        checkNotes(
          iosNotes: '• New things',
          playNotesJson: play([
            {'language': 'en-US', 'text': '• New things'},
          ]),
        ),
        isEmpty,
      );
    });

    test('flag Punjabi, which Google Play has no notes for', () {
      final problems = checkNotes(
        iosNotes: 'x',
        playNotesJson: play([
          {'language': 'pa', 'text': 'ਨਵਾਂ'},
        ]),
      );
      expect(problems.single, contains('English only'));
    });

    test('flag notes over each store\'s limit', () {
      final problems = checkNotes(
        iosNotes: 'a' * 4001,
        playNotesJson: play([
          {'language': 'en-GB', 'text': 'b' * 501},
        ]),
      );
      expect(problems, hasLength(2));
    });

    test('flag empty iPhone notes and broken JSON', () {
      expect(checkNotes(iosNotes: '  ', playNotesJson: '[{'), hasLength(2));
    });

    test('the files in the repo pass', () {
      expect(
        checkNotes(
          iosNotes: File('ios/whats_new.txt').readAsStringSync(),
          playNotesJson: File('release_notes.json').readAsStringSync(),
        ),
        isEmpty,
      );
    });
  });

  group('the store pages', () {
    test('Google Play: the version in the page data', () {
      expect(
        playVersionFromPage('…"2.0.1"…,[[["2.2.0"]],[[[35,"15"]]]…'),
        '2.2.0',
      );
      expect(playVersionFromPage('<html>no data</html>'), isNull);
    });

    test('App Store: the version on sale, or none', () {
      expect(
        appStoreVersionFromLookup(
            '{"resultCount":1,"results":[{"version":"3.0.0"}]}'),
        '3.0.0',
      );
      expect(
          appStoreVersionFromLookup('{"resultCount":0,"results":[]}'), isNull);
    });
  });

  test('a build reads as 1 line per step', () {
    expect(
      describeBuild({
        'status': 'finished',
        'buildActions': [
          {'name': 'Building Android', 'status': 'success'},
          {'name': 'Publishing', 'status': null},
        ],
      }),
      ['status: finished', '  success  Building Android', '  -  Publishing'],
    );
  });

  test('build publishes only with --confirm', () {
    // An agent passes --confirm only after Hark asks for that build.
    final source = File('tool/release.dart').readAsStringSync();
    expect(source, contains("if (!args.contains('--confirm'))"));
  });
}
