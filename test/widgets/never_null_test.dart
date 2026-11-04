import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/source_index.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SGPC's feed turned a missing value into the word "null". The reader must
/// not show it, in either language.
class _NullFeed extends HukamnamaController {
  @override
  Future<Hukamnama> build() async {
    final json = jsonDecode(
      File('test/fixtures/sgpc_hukamnama_2026_11_02.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    (json['hukamnama'] as Map<String, dynamic>).addAll({
      'gheading1': 'null',
      'eheading1': 'null',
      'ghukamnamadesc': 'null',
      'ehukamnamadesc': 'NULL',
      'gfooter1': 'null',
      'efooter1': 'null',
    });
    return Hukamnama.fromSgpc(json);
  }
}

class _Locale extends LocaleController {
  _Locale(this.locale);

  final String locale;

  @override
  String build() => locale;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in ['en', 'pa']) {
    testWidgets('the reader shows no "null", $locale', (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hukamnamaProvider.overrideWith(_NullFeed.new),
            localeController.overrideWith(() => _Locale(locale)),
            sangrandTableProvider.overrideWith((ref) async => null),
            nowPlayingProvider.overrideWithValue(
              const NowPlaying(
                index: kLiveIndex,
                action: PlayAction.play,
                started: false,
                live: LivePlaybackState(),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.material,
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HukamnamaScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining(RegExp('null', caseSensitive: false)), findsNothing);
      // The text itself is still there.
      expect(find.textContaining('ਹਰਿ ਹਰਿ ਬੂੰਦ'), findsWidgets);
    });
  }
}
