/// The release of an installed version, as the "what's new" files name it:
/// its major and minor number. `3.1.0 (11)` is release `3.1`. A patch release
/// is the same release, so it never asks again.
///
/// Null when [shown] has no version at the start.
String? releaseOf(String shown) {
  final match = RegExp(r'^\s*(\d+)\.(\d+)').firstMatch(shown);
  return match == null ? null : '${match[1]}.${match[2]}';
}

/// What to do about "what's new" on this launch.
enum WhatsNewAction {
  /// Nothing. This release was shown or recorded already.
  nothing,

  /// Record this release as seen, and show nothing: a fresh install, or a
  /// release with no notes.
  record,

  /// Show the notes, once.
  show,
}

/// Decides, from facts the app already has.
///
/// - [seen] is the release that was saved as seen, or null before the first
///   time. [release] is the installed one.
/// - [hasNotes] is whether the release has a file of notes.
/// - [existingInstall] is whether the app has saved anything else before. A
///   listener who updates from a build that did not keep [seen] still has
///   their language, their reminder or their place saved, and a fresh install
///   has none of it at the first launch. When unsure, the answer is "fresh":
///   a note that is missed costs less than a note shown to someone who has
///   just installed the app.
WhatsNewAction decideWhatsNew({
  required String? seen,
  required String release,
  required bool hasNotes,
  required bool existingInstall,
}) {
  if (seen == release) return WhatsNewAction.nothing;
  if (seen == null && !existingInstall) return WhatsNewAction.record;
  if (!hasNotes) return WhatsNewAction.record;
  return WhatsNewAction.show;
}
