import 'package:flutter/foundation.dart';
import 'package:live_darbar/src/core/display_text.dart';

/// A message from `release.json` for when the backend is down or changing.
///
/// ```json
/// "maintenance": { "en": "...", "pa": "..." }
/// ```
///
/// It shows as a calm banner. The app keeps working: it plays what it can. A
/// file with no `maintenance` key, or with no message in it, has none, so
/// today's file keeps today's behaviour. A string in place of the object is
/// the message in both languages.
@immutable
class Maintenance {
  const Maintenance({this.en, this.pa}) : assert(en != null || pa != null);

  final String? en;
  final String? pa;

  /// The message in [localeCode], or in the other language when this one has
  /// none: a listener should read a message, not a gap.
  String messageFor(String localeCode) =>
      (localeCode == 'pa' ? pa ?? en : en ?? pa)!;

  /// Null when the manifest has no message that is fit to show.
  static Maintenance? fromManifest(Map<String, dynamic> json) {
    final raw = json['maintenance'];
    final String? en;
    final String? pa;
    if (raw is Map) {
      en = displayText(raw['en']);
      pa = displayText(raw['pa']);
    } else {
      en = pa = displayText(raw);
    }
    if (en == null && pa == null) return null;
    return Maintenance(en: en, pa: pa);
  }

  @override
  bool operator ==(Object other) =>
      other is Maintenance && other.en == en && other.pa == pa;

  @override
  int get hashCode => Object.hash(en, pa);
}
