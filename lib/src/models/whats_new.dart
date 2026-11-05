import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/core/display_text.dart';

/// One new thing, in both languages.
@immutable
class WhatsNewItem {
  const WhatsNewItem({
    required this.titleEn,
    required this.titlePa,
    this.bodyEn,
    this.bodyPa,
  });

  final String titleEn;
  final String titlePa;

  /// One line under the title, or null.
  final String? bodyEn;
  final String? bodyPa;

  String titleFor(String locale) => locale == 'pa' ? titlePa : titleEn;
  String? bodyFor(String locale) => locale == 'pa' ? bodyPa : bodyEn;
}

/// The new things of one release, from `assets/whats_new/<release>.json`.
///
/// ```json
/// {
///   "release": "3.1",
///   "items": [
///     {
///       "title": {"en": "...", "pa": "..."},
///       "body": {"en": "...", "pa": "..."}
///     }
///   ]
/// }
/// ```
///
/// An item needs a title in both languages. The body is optional. The sheet is
/// calm, so it shows the first [maxItems] items. The next release adds a
/// file and no code.
///
/// An item that is new on some platforms only names them in `"only"`, for
/// example `"only": ["ios"]` for the iPhone widget. The names are those of
/// [whatsNewPlatform]. An item with no `"only"` shows everywhere.
@immutable
class WhatsNew {
  const WhatsNew({required this.release, required this.items});

  static const maxItems = 5;

  /// The release these notes are for, for example `3.1`.
  final String release;
  final List<WhatsNewItem> items;

  /// Null when the file names no release or has no usable item.
  ///
  /// [platform] leaves out each item whose `"only"` does not name it. With no
  /// [platform], every item stays.
  static WhatsNew? fromJson(Object? json, {String? platform}) {
    if (json is! Map) return null;
    final release = displayText(json['release']);
    final raw = json['items'];
    if (release == null || raw is! List) return null;

    String? text(Object? map, String language) =>
        map is Map ? displayText(map[language]) : null;

    bool isFor(Object? only) => switch (only) {
          null => true,
          _ when platform == null => true,
          final String name => name == platform,
          final List names => names.contains(platform),
          _ => false,
        };

    final items = <WhatsNewItem>[];
    for (final item in raw) {
      if (item is! Map || !isFor(item['only'])) continue;
      final titleEn = text(item['title'], 'en');
      final titlePa = text(item['title'], 'pa');
      if (titleEn == null || titlePa == null) continue;
      items.add(
        WhatsNewItem(
          titleEn: titleEn,
          titlePa: titlePa,
          bodyEn: text(item['body'], 'en'),
          bodyPa: text(item['body'], 'pa'),
        ),
      );
      if (items.length == maxItems) break;
    }
    if (items.isEmpty) return null;
    return WhatsNew(release: release, items: items);
  }
}

/// The name that `"only"` uses for the platform the app runs on: `web`,
/// `android`, `ios`, `macos`, and so on.
String whatsNewPlatform({bool web = kIsWeb, TargetPlatform? target}) =>
    web ? 'web' : (target ?? defaultTargetPlatform).name.toLowerCase();
