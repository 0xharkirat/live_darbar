/// The widget's refresh while the app is closed.
///
/// Android's WorkManager wakes the app's process a few times a day (see
/// `WidgetRefresh.kt`). The worker starts [widgetRefreshMain] (through
/// `widgetRefreshEntry` in main.dart) in a Flutter engine of its own. The run
/// looks for today's Hukamnama through the same [HukamnamaService] and the
/// same disk cache as the app, makes the widget's text, and hands it back to
/// the worker.
///
/// ## Why the engine has no plugins
///
/// The worker starts the engine with plugin registration off. A second engine
/// that registered every plugin would register `audio_service` a second time.
/// That plugin keeps its state in statics, and tearing the second copy down
/// clears the statics that the playing app still uses. A refresh at the
/// moment someone listens would break the media session. So this run uses
/// only what needs no plugin: `dart:io` for the network, a directory path
/// from the worker instead of `path_provider`, and the worker itself, over a
/// channel, to write the store.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/home_screen_widget/widget_data.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/hukamnama_cache.dart';
import 'package:live_darbar/src/services/hukamnama_loader.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';

/// The channel to the worker. Its name is the one in WidgetRefreshWorker.kt.
const kWidgetWorkerChannel = 'com.hsi.harki.live_darbar/widget_worker';

/// What one background run found.
class WidgetRefresh {
  const WidgetRefresh({required this.data, required this.current});

  /// The text to store. See [buildWidgetData].
  final Map<String, String> data;

  /// Whether the Hukamnama in [data] is today's. False before SGPC posts it,
  /// and after a failed request. The worker asks WorkManager to try again
  /// when this is false in the morning run.
  final bool current;
}

/// Makes the widget's text with whatever the phone can reach right now.
///
/// It never throws for a network failure. It falls back to the text on disk,
/// and to no Hukamnama at all when there is none, so the widget's date still
/// moves on.
Future<WidgetRefresh> prepareWidgetRefresh({
  required String language,
  required DateTime now,
  required HukamnamaService service,
  required HukamnamaCache cache,
}) async {
  final today = sgpcDayOf(now);

  Hukamnama? text = await cache.readLatest();
  if (text == null || !text.isFor(today)) {
    try {
      text = await loadLatestHukamnama(
        service: service,
        cache: cache,
        today: today,
        have: text,
      );
    } catch (e) {
      // Nothing on disk and nothing from the network. The date is still worth
      // writing.
      if (!kReleaseMode) debugPrint('[widget refresh] no Hukamnama: $e');
    }
  }

  await initializeDateFormatting(language);
  final data = buildWidgetData(
    now: now,
    language: language,
    l10n: lookupAppLocalizations(Locale(language)),
    hukamnama: text,
  );
  return WidgetRefresh(data: data, current: text?.isFor(today) ?? false);
}

/// The entry point the worker starts. [args] is the app's language, then the
/// path of the app's support directory, which holds the Hukamnama cache.
///
/// It publishes the text over the channel, then says it is done. The worker
/// keeps the engine alive until then and ends it afterward.
@pragma('vm:entry-point')
Future<void> widgetRefreshMain(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(kWidgetWorkerChannel);

  var current = false;
  final service = HukamnamaService();
  try {
    final directory = Directory(args[1]);
    final refresh = await prepareWidgetRefresh(
      language: widgetLanguage(args[0]),
      now: DateTime.now(),
      service: service,
      cache: HukamnamaCache(directory: () async => directory),
    );
    await channel.invokeMethod<void>('publish', refresh.data);
    current = refresh.current;
  } catch (e) {
    if (!kReleaseMode) debugPrint('[widget refresh] failed: $e');
  } finally {
    service.close();
  }
  await channel.invokeMethod<void>('done', current);
}
