import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/home_screen_widget/widget_actions.dart';
import 'package:live_darbar/src/home_screen_widget/widget_background.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/home_screen_widget/widget_links.dart';
import 'package:live_darbar/src/home_screen_widget/widget_playback.dart';
import 'package:live_darbar/src/home_screen_widget/widget_remote.dart';
import 'package:live_darbar/src/media_session/media_catalog.dart';
import 'package:live_darbar/src/models/source_index.dart';

/// The Dart side and the Kotlin side of the widget share names. Nothing
/// compiles them together, so a rename on one side would break the widget
/// without a failing build. These tests read the native files and compare.
const _kotlin = 'android/app/src/main/kotlin/com/hsi/harki/live_darbar';
const _manifest = 'android/app/src/main/AndroidManifest.xml';

const _res = 'android/app/src/main/res';

String read(String path) => File(path).readAsStringSync();

/// The opening tag of the view with [id], attributes and all.
String openingTag(String layout, String id) {
  final match =
      RegExp('<\\w+\\s+android:id="@\\+id/$id"[^>]*>').firstMatch(layout);
  expect(match, isNotNull, reason: 'no view with id $id');
  return match!.group(0)!;
}

void main() {
  group('the store keys', () {
    final store = read('$_kotlin/widget/WidgetStore.kt');

    // Kotlin: `private const val LINE = "ld_line"`.
    final kotlinKeys = {
      for (final m in RegExp(r'const val (\w+) = "(ld_\w+)"').allMatches(store))
        m.group(2)!,
    };

    test('Kotlin reads exactly the keys that Dart writes', () {
      final dartKeys = {
        WidgetKeys.language,
        WidgetKeys.title,
        WidgetKeys.dates,
        WidgetKeys.line,
        WidgetKeys.hukamnamaMeta,
        WidgetKeys.openLabel,
        WidgetKeys.labels,
        WidgetKeys.playback,
      };
      expect(kotlinKeys, dartKeys);
    });

    test('the store file is the one home_widget writes', () {
      expect(store, contains('"HomeWidgetPreferences"'));
    });

    test('the top line\'s separator is the one Dart joins with', () {
      expect(store, contains('SEPARATOR = " · "'));
    });
  });

  group('the widget provider', () {
    test('Dart names the class that the manifest and Kotlin declare', () {
      final source = read('$_kotlin/widget/LiveDarbarWidgetProvider.kt');
      final package = RegExp(r'^package ([\w.]+)', multiLine: true)
          .firstMatch(source)!
          .group(1);
      final name = RegExp(r'^class (\w+) : AppWidgetProvider', multiLine: true)
          .firstMatch(source)!
          .group(1);
      expect(kWidgetProviderClass, '$package.$name');

      // The manifest writes the name relative to the app's package.
      expect(read(_manifest), contains('android:name=".widget.$name"'));
    });

    test('the manifest points at the provider info and the info at the layouts',
        () {
      expect(
        read(_manifest),
        contains('android:resource="@xml/live_darbar_widget_info"'),
      );
      final info =
          read('android/app/src/main/res/xml/live_darbar_widget_info.xml');
      expect(info, contains('@layout/widget_medium'));
      expect(info, contains('@drawable/widget_preview'));
      expect(info, contains('@string/widget_description'));
      expect(
        File('android/app/src/main/res/drawable-nodpi/widget_preview.png')
            .existsSync(),
        isTrue,
      );
    });
  });

  group('the taps that open a screen', () {
    final actions = read('$_kotlin/widget/WidgetActions.kt');

    test('the one action is a fixed string in the app\'s namespace', () {
      expect(
        actions,
        contains(
          'OPEN_HUKAMNAMA = "com.hsi.harki.live_darbar.OPEN_HUKAMNAMA"',
        ),
      );
      // The player has no way in from the widget. Its notification opens it.
      expect(actions, isNot(contains('OPEN_PLAYER')));
    });

    test('Kotlin sends the command that Dart handles', () {
      expect(actions, contains('OPEN_HUKAMNAMA -> "$kOpenHukamnamaCommand"'));
      expect(read('lib/main.dart'), contains('case kOpenHukamnamaCommand:'));
    });

    test('the widget can no longer start playback through MainActivity', () {
      // Playing goes to the media session. A screen opening to play was the
      // old way, and an intent that plays is one more way in.
      expect(actions, isNot(contains('PLAY_LIVE')));
    });

    test('anything but that action maps to no command', () {
      // The `when` has exactly the one fixed case and an `else -> null`.
      final body =
          RegExp(r'fun commandFor[\s\S]*?\n    }').firstMatch(actions)!;
      expect(RegExp(r'->').allMatches(body.group(0)!).length, 2);
      expect(body.group(0), contains('else -> null'));
    });

    test('the manifest does not open the actions to implicit intents', () {
      // The widget uses explicit intents. A filter would add a way in.
      final manifest = read(_manifest);
      expect(manifest, isNot(contains('OPEN_PLAYER')));
      expect(manifest, isNot(contains('OPEN_HUKAMNAMA')));
    });

    test('the widget builds them as immutable, explicit intents', () {
      final renderer = read('$_kotlin/widget/WidgetRenderer.kt');
      expect(renderer, contains('Intent(context, MainActivity::class.java)'));
      expect(renderer, contains('PendingIntent.FLAG_IMMUTABLE'));
      expect(renderer, isNot(contains('putExtra')));
    });

    test('MainActivity maps an action through commandFor and reads no extras',
        () {
      final main = read('$_kotlin/MainActivity.kt');
      expect(main, contains('WidgetActions.commandFor(action)'));
      expect(main, isNot(contains('getStringExtra')));
    });
  });

  group('the controls, which play with no screen', () {
    final playback = read('$_kotlin/widget/WidgetPlayback.kt');
    final receiver = read('$_kotlin/widget/WidgetControlReceiver.kt');
    final renderer = read('$_kotlin/widget/WidgetRenderer.kt');
    final manifest = read(_manifest);

    test('the receiver is declared, and not exported', () {
      final tag = RegExp(
        r'<receiver\s+android:name="\.widget\.WidgetControlReceiver"[^>]*>',
      ).firstMatch(manifest);
      expect(tag, isNotNull);
      expect(tag!.group(0), contains('android:exported="false"'));
      // No filter: nothing but the widget's own PendingIntents reaches it.
      expect(
        RegExp(
          r'WidgetControlReceiver"[^>]*>\s*<intent-filter',
        ).hasMatch(manifest),
        isFalse,
      );
    });

    test('the four commands are fixed strings, found by the whole string', () {
      for (final name in ['PLAY_LIVE', 'STOP', 'PLAY_HUKAMNAMA', 'PAUSE']) {
        expect(
          playback,
          contains('$name("com.hsi.harki.live_darbar.widget.$name")'),
        );
      }
      expect(
          playback, contains('values().firstOrNull { it.action == action }'));
    });

    test('the widget sends them as immutable broadcasts to the receiver', () {
      expect(
        renderer,
        contains('Intent(context, WidgetControlReceiver::class.java)'),
      );
      expect(renderer, contains('PendingIntent.getBroadcast'));
      expect(renderer, contains('PendingIntent.FLAG_IMMUTABLE'));
      // The receiver reads the action and nothing else.
      expect(receiver, isNot(contains('getStringExtra')));
      expect(receiver, isNot(contains('getExtras')));
    });

    test('it starts the audio service as a foreground service, then binds', () {
      expect(receiver, contains('context.startForegroundService(intent)'));
      expect(receiver, contains('Intent(context, AudioService::class.java)'));
      expect(receiver, contains('MediaBrowserCompat('));
      expect(receiver, contains('transportControls'));
    });

    test('it sends the ids that Android Auto plays from', () {
      // playFromMediaId with the media session's own ids, as the car does.
      expect(
          receiver, contains('controls.playFromMediaId(Source.LIVE.mediaId'));
      expect(
        receiver,
        contains('controls.playFromMediaId(Source.HUKAMNAMA.mediaId'),
      );
      expect(receiver, contains('controls.pause()'));
      expect(receiver, contains('controls.stop()'));

      for (final (source, index) in [
        ('LIVE("live"', kLiveIndex),
        ('HUKAMNAMA("hukamnama"', kMukhwakIndex),
        ('KATHA("katha"', kKathaIndex),
      ]) {
        expect(
          playback,
          contains('$source, "${MediaCatalog.idFor(index)}")'),
          reason: source,
        );
      }
    });

    test('a play stops the service before the system\'s 10 second limit', () {
      expect(receiver, contains('WATCHDOG_MS = 7_000L'));
      expect(receiver, contains('context.stopService('));
    });

    test('Kotlin and Dart say the playback in the same words', () {
      for (final state in WidgetPlayState.values) {
        expect(
            playback, contains('${state.name.toUpperCase()}("${state.name}")'));
      }
      for (final source in WidgetSource.values) {
        expect(playback,
            contains('${source.name.toUpperCase()}("${source.name}"'));
      }
      // The keys of the stored JSON.
      final store = read('$_kotlin/widget/WidgetStore.kt');
      expect(store, contains('"state"'));
      expect(store, contains('"source"'));
      expect(store, contains('"at"'));
      expect(store, contains('"by"'));
      // Who wrote it: Dart says app, the widget says widget.
      expect(store, contains('.put("by", "widget")'));
      expect(
        encodeWidgetPlayback(
          WidgetPlayback.idle,
          at: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        contains('"by":"app"'),
      );
    });

    test('a state from a process that has ended is not believed', () {
      expect(playback, contains('stored.atMs < processStartMs'));
      expect(
        read('$_kotlin/widget/WidgetStore.kt'),
        contains('Process.getStartElapsedRealtime()'),
      );
      // Every draw goes through the rule.
      expect(
        read('$_kotlin/widget/WidgetStore.kt'),
        contains('WidgetPlayback.reconcile('),
      );
    });

    test('the background refresh cannot write the playback', () {
      // Its engine has no media session. It may write text, never the state.
      final store = read('$_kotlin/widget/WidgetStore.kt');
      final keys = RegExp(r'private val KEYS = listOf\(([\s\S]*?)\)')
          .firstMatch(store)!
          .group(1)!;
      expect(keys, isNot(contains('PLAYBACK')));
    });

    test('the media library the receiver binds with is a declared dependency',
        () {
      expect(
        read('android/app/build.gradle'),
        contains('implementation "androidx.media:media:'),
      );
    });
  });

  group('the background refresh', () {
    final worker = read('$_kotlin/widget/WidgetRefresh.kt');

    test('Kotlin starts the entry point that main.dart declares', () {
      final entry = RegExp(r'const val DART_ENTRY = "(\w+)"')
          .firstMatch(worker)!
          .group(1);
      expect(
        read('lib/main.dart'),
        contains('@pragma(\'vm:entry-point\')\nFuture<void> $entry('),
      );
    });

    test('both sides use the same channel', () {
      expect(worker, contains('CHANNEL = "$kWidgetWorkerChannel"'));
    });

    test('the engine starts with plugin registration off', () {
      // A second engine with audio_service registered would break playback.
      expect(worker, contains('FlutterEngine(context, null, false)'));
    });

    test('the worker is booked in India time, after midnight and mid-morning',
        () {
      expect(worker, contains('MIDNIGHT("midnight", 10)'));
      expect(worker, contains('MORNING("morning", 9 * 60)'));
      expect(worker, contains('IST_OFFSET_MS = 19_800_000L'));
    });

    test('the manifest needs no permission for it', () {
      // WorkManager brings its own. No alarm or boot permission is added.
      final manifest = read(_manifest);
      expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
      expect(manifest, isNot(contains('RECEIVE_BOOT_COMPLETED')));
    });

    test('the Dart arguments are the language and the support directory', () {
      expect(worker, contains('listOf(language, context.filesDir.path)'));
    });
  });

  group('the layouts', () {
    final medium = read('$_res/layout/widget_medium.xml');

    test('the gold button has a ripple of its own, dark on the gold', () {
      // A light ripple on gold cannot be seen, and a plain shape shows nothing.
      for (final name in ['widget_button_gold', 'widget_button_gold_loading']) {
        final button = read('$_res/drawable/$name.xml');
        expect(button, contains('<ripple'), reason: name);
        expect(button, contains('#400C0A09'), reason: name);
        expect(button, contains('@android:id/mask'), reason: name);
      }
    });

    test('the loading button is the gold dimmed, and the glyph is still dots',
        () {
      expect(
        read('$_res/drawable/widget_button_gold_loading.xml'),
        contains('#99E8B04B'),
      );
      expect(File('$_res/drawable/ic_widget_loading.xml').existsSync(), isTrue);
    });

    test('both buttons are 48 dp targets, with a ripple', () {
      // Each is a 40 dp capsule inside a 48 dp target.
      for (final name in [
        'widget_pill',
        'widget_pill_ripple',
        'widget_button_gold',
        'widget_button_gold_loading'
      ]) {
        expect(read('$_res/drawable/$name.xml'), contains('insetTop="4dp"'),
            reason: name);
      }
      final hukamnama = openingTag(medium, 'widget_hukamnama_button');
      expect(hukamnama, contains('android:layout_height="48dp"'));
      expect(
        hukamnama,
        contains('android:foreground="@drawable/widget_pill_ripple"'),
      );
      // The gold button is its own ripple, as the background of its view.
      final live = openingTag(medium, 'widget_live_button');
      expect(live, contains('android:layout_height="48dp"'));
      expect(
        live,
        contains('android:background="@drawable/widget_button_gold"'),
      );
    });

    test('one layout, with the Rahao line and the two buttons side by side',
        () {
      expect(File('$_res/layout/widget_compact.xml').existsSync(), isFalse);
      expect(medium, contains('@+id/widget_line"'));
      expect(medium, contains('@+id/widget_hukamnama_button"'));
      expect(openingTag(medium, 'widget_live_button'),
          contains('layout_weight="1"'));
      // The old controls are gone: no Listen word, no live mark.
      expect(medium, isNot(contains('widget_listen')));
      expect(medium, isNot(contains('widget_mark')));
    });

    test('the widget stays 4 cells wide, and resizes in height only', () {
      // At 3 cells the button names are cut, and at 2 the Rahao line goes.
      final info = read('$_res/xml/live_darbar_widget_info.xml');
      expect(info, contains('android:targetCellWidth="4"'));
      expect(info, contains('android:minWidth="250dp"'));
      expect(info, contains('android:resizeMode="vertical"'));
    });

    test('a tap away from the buttons opens the reader', () {
      final renderer = read('$_kotlin/widget/WidgetRenderer.kt');
      expect(
        renderer,
        contains(
          'R.id.widget_root, open(context, REQUEST_READER, WidgetActions.OPEN_HUKAMNAMA)',
        ),
      );
    });

    test('each button has a content description, filled in by state', () {
      final renderer = read('$_kotlin/widget/WidgetRenderer.kt');
      expect(renderer,
          contains('views.setContentDescription(button, description)'));
      expect(renderer, contains('button = R.id.widget_live_button'));
      expect(renderer, contains('button = R.id.widget_hukamnama_button'));
    });

    test('a resize needs no redraw, because there is one layout', () {
      final renderer = read('$_kotlin/widget/WidgetRenderer.kt');
      expect(renderer,
          contains('RemoteViews(context.packageName, R.layout.widget_medium)'));
      expect(renderer, isNot(contains('widget_compact')));
      expect(
        read('$_kotlin/widget/LiveDarbarWidgetProvider.kt'),
        isNot(contains('onAppWidgetOptionsChanged')),
      );
    });

    test('the top line is one line, and shrinks before it cuts the Ang', () {
      final heading = openingTag(medium, 'widget_heading');
      expect(heading, contains('android:maxLines="1"'));
      expect(heading, contains('android:autoSizeTextType="uniform"'));
    });
  });

  group('text size', () {
    final layouts = {
      'medium': read('$_res/layout/widget_medium.xml'),
    };

    test('no text is under 11 sp, and Gurbani never shrinks under 12 sp', () {
      final size =
          RegExp(r'android:(?:textSize|autoSizeMinTextSize)="(\d+)sp"');
      for (final MapEntry(:key, :value) in layouts.entries) {
        for (final m in size.allMatches(value)) {
          expect(int.parse(m.group(1)!), greaterThanOrEqualTo(11), reason: key);
        }
      }
      final min = RegExp(r'android:autoSizeMinTextSize="(\d+)sp"')
          .firstMatch(openingTag(layouts['medium']!, 'widget_line'));
      expect(int.parse(min!.group(1)!), greaterThanOrEqualTo(12));
    });

    test('the button names are 14 sp', () {
      for (final MapEntry(:key, :value) in layouts.entries) {
        for (final id in ['widget_hukamnama_word', 'widget_live_word']) {
          expect(
            openingTag(value, id),
            contains('android:textSize="14sp"'),
            reason: '$key $id',
          );
        }
      }
    });

    test('the Gurbani line adds no line spacing, so it can stay large', () {
      // Tiro Gurmukhi is already 1.3 times its size tall per line. Extra
      // spacing makes the autosizing choose a smaller size to fit 2 lines.
      expect(
        openingTag(layouts['medium']!, 'widget_line'),
        isNot(contains('lineSpacing')),
      );
    });
  });

  group('the picker preview', () {
    final info = read('$_res/xml/live_darbar_widget_info.xml');

    test('Android 12 and newer show a still layout, older ones the image', () {
      expect(info, contains('android:previewLayout="@layout/widget_preview"'));
      expect(info, contains('android:previewImage="@drawable/widget_preview"'));
      expect(File('$_res/layout/widget_preview.xml').existsSync(), isTrue);
    });

    test('the still layout holds fixed text only, and no taps or ids', () {
      final preview = read('$_res/layout/widget_preview.xml');
      expect(preview, isNot(contains('android:id=')));
      expect(preview, isNot(contains('android:foreground')));
      for (final m in RegExp(r'android:text="([^"]+)"').allMatches(preview)) {
        expect(
          m.group(1),
          anyOf(
            startsWith('@string/widget_preview_'),
            '@string/widget_hukamnama',
            '@string/widget_live_kirtan',
          ),
        );
      }
      expect(preview, contains('style="@style/WidgetGurbani"'));
    });

    test('it says the same words as the real widget, in both languages', () {
      final english = read('$_res/values/widget_preview.xml');
      final punjabi = read('$_res/values-pa/widget_preview.xml');
      // The date and the Ang are written in Gurmukhi digits in Punjabi.
      expect(english, contains('>" · 2 Nov · Ang 668"<'));
      expect(punjabi, contains('>" · ੨ ਨਵੰ · ਅੰਗ ੬੬੮"<'));
      // The Gurbani is the same in both, so it is written once.
      expect(english, contains('name="widget_preview_line"'));
      expect(punjabi, isNot(contains('widget_preview_line')));
    });
  });

  group('the Gurbani face', () {
    test('Android 8 and newer draw the app\'s Tiro Gurmukhi', () {
      final newer = read('$_res/values-v26/widget.xml');
      expect(newer, contains('name="WidgetGurbani"'));
      expect(newer, contains('@font/tirogurmukhi'));
    });

    test('older phones keep the system serif', () {
      final base = read('$_res/values/widget.xml');
      expect(base, contains('name="WidgetGurbani"'));
      expect(base, contains('<item name="android:fontFamily">serif</item>'));
    });

    test('the Rahao line takes the face from that style, not its own', () {
      final line =
          openingTag(read('$_res/layout/widget_medium.xml'), 'widget_line');
      expect(line, contains('style="@style/WidgetGurbani"'));
      expect(line, isNot(contains('fontFamily')));
    });

    test('the font file is the very file the app ships', () {
      // The copy in res/font is the only way a widget can load it. If the app
      // changes its face, the widget must change too.
      expect(
        File('$_res/font/tirogurmukhi.ttf').readAsBytesSync(),
        File('assets/fonts/TiroGurmukhi-400.ttf').readAsBytesSync(),
      );
    });
  });

  group('letter spacing', () {
    test('no native text sets any, because Gurmukhi must never have it', () {
      for (final path in [
        'android/app/src/main/res/layout/widget_medium.xml',
        '$_kotlin/widget/WidgetRenderer.kt',
      ]) {
        expect(
          read(path).toLowerCase(),
          isNot(anyOf(contains('letterspacing'), contains('letter_spacing'))),
          reason: path,
        );
      }
    });
  });

  group('the iPhone widget', () {
    const swift = 'ios/LiveDarbarWidget';
    final store = read('$swift/WidgetStore.swift');
    final view = read('$swift/LiveDarbarWidgetView.swift');
    final widget = read('$swift/LiveDarbarWidget.swift');
    final delegate = read('ios/Runner/AppDelegate.swift');

    test('Swift reads exactly the keys that Dart writes', () {
      final swiftKeys = {
        for (final m
            in RegExp(r'static let \w+ = "(ld_\w+)"').allMatches(store))
          m.group(1)!,
      };
      expect(swiftKeys, {
        WidgetKeys.language,
        WidgetKeys.title,
        WidgetKeys.dates,
        WidgetKeys.line,
        WidgetKeys.hukamnamaMeta,
        WidgetKeys.openLabel,
        WidgetKeys.labels,
        WidgetKeys.playback,
      });
      expect(store, contains('separator = " · "'));
    });

    test('the app and the widget name the same App Group', () {
      expect(store, contains('appGroup = "$kIosAppGroupId"'));
      expect(delegate, contains('suiteName: "$kIosAppGroupId"'));
      for (final entitlements in [
        'ios/Runner/Runner.entitlements',
        '$swift/LiveDarbarWidget.entitlements',
      ]) {
        expect(read(entitlements), contains('<string>$kIosAppGroupId</string>'),
            reason: entitlements);
      }
    });

    test('the app reloads the widget by its kind', () {
      expect(widget, contains('kind = "$kIosWidgetKind"'));
      expect(delegate, contains('ofKind: "$kIosWidgetKind"'));
    });

    test('each link the widget opens is one the app reads', () {
      final parts = [
        for (final m in RegExp(r'link\("(\w+)"\)').allMatches(view))
          m.group(1)!,
      ];
      expect(parts, ['live', 'hukamnama', 'open']);
      final template =
          RegExp(r'URL\(string: "([^"]+)"\)').firstMatch(view)!.group(1)!;
      expect(
        [
          for (final part in parts)
            widgetLinkFrom(Uri.parse(template.replaceAll(r'\(part)', part))),
        ],
        [WidgetLink.live, WidgetLink.hukamnama, WidgetLink.open],
      );
      expect(template, contains('homeWidget'));
      expect(
        read('ios/Runner/Info.plist'),
        contains('<string>$kWidgetLinkScheme</string>'),
      );
    });

    test('Swift reads the playback states by the names Dart writes', () {
      for (final state in [WidgetPlayState.loading, WidgetPlayState.playing]) {
        expect(store, contains('"${state.name}"'));
      }
      for (final source in [WidgetSource.live, WidgetSource.hukamnama]) {
        expect(store, contains('source == "${source.name}"'));
      }
      expect(delegate, contains(r'\"state\":\"idle\"'));
    });
  });

  group('the iPhone widget\'s play buttons', () {
    final intents = read('ios/Runner/WidgetPlayIntents.swift');
    final host = read('ios/Runner/WidgetPlayHost.swift');
    final project = read('ios/Runner.xcodeproj/project.pbxproj');

    test('the intent and Dart share the channel, the group and the store', () {
      expect(host, contains('channelName = "$kWidgetControlChannel"'));
      expect(intents, contains('appGroup = "$kIosAppGroupId"'));
      expect(intents, contains('widgetKind = "$kIosWidgetKind"'));
      expect(intents, contains('playbackKey = "${WidgetKeys.playback}"'));
    });

    test('the intent names the sources that Dart names', () {
      final cases = {
        for (final m in RegExp(r'case (\w+)\n').allMatches(
          RegExp(r'enum WidgetPlaySource[^{]*\{([^}]*)\}')
              .firstMatch(intents)!
              .group(1)!,
        ))
          m.group(1)!,
      };
      expect(cases, {WidgetSource.live.name, WidgetSource.hukamnama.name});
      // The tap writes the same shape that encodeWidgetPlayback writes.
      expect(intents, contains(r'\"state\":\"loading\"'));
      expect(intents, contains(r'\"by\":\"widget\"'));
    });

    test('each button is an audio intent that does not open the app', () {
      expect(
        RegExp(r': AudioPlaybackIntent').allMatches(intents).length,
        2,
      );
      expect(
        RegExp(r'openAppWhenRun: Bool = false').allMatches(intents).length,
        2,
      );
    });

    test('the intents are in the app and in the widget, the host in the app',
        () {
      // A file that is a member of a target has a build file for it.
      int members(String file) =>
          RegExp('$file in Sources \\*/ = \\{isa = PBXBuildFile')
              .allMatches(project)
              .length;
      expect(members('WidgetPlayIntents.swift'), 2);
      expect(members('WidgetPlayHost.swift'), 1);
      expect(members('SceneDelegate.swift'), 1);
      // Only the app has Flutter, and the flag keeps it out of the widget's copy.
      expect(
        RegExp(r'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "\$\(inherited\) LIVE_DARBAR_APP"')
            .allMatches(project)
            .length,
        3,
        reason: 'Debug, Release and Profile of Runner, and no other target',
      );
      expect(intents, contains('#if LIVE_DARBAR_APP'));
      expect(read('ios/LiveDarbarWidget/LiveDarbarWidgetView.swift'),
          contains('Toggle(isOn: isOn, intent:'));
    });

    test('one engine: the scene shows the app delegate\'s, not a storyboard\'s',
        () {
      final plist = read('ios/Runner/Info.plist');
      expect(plist, contains('<string>SceneDelegate</string>'));
      expect(plist, isNot(contains('UISceneStoryboardFile')));
      expect(plist, isNot(contains('UIMainStoryboardFile')));
      expect(read('ios/Runner/SceneDelegate.swift'),
          contains('FlutterViewController('));
      expect(read('ios/Runner/AppDelegate.swift'),
          contains('GeneratedPluginRegistrant.register(with: engine)'));
    });
  });
}
