/// The one guard for text that comes from outside the app and is shown to a
/// listener: SGPC's feed, the calendar of events, release.json.
///
/// A feed that has no value for a field often writes `null`, an empty string,
/// or the 4 letters "null" in a string, because a server turned a missing
/// value into text. Shown as it is, the listener reads "null" on the screen.
/// This hides all 3, so each place that shows feed text goes through it, and
/// a scattered `?? ''` does not have to cover the cases 1 by 1.
///
/// [value] trimmed, or null when it is not a string, is blank, or is the word
/// "null" in any case. Text that only contains the word, such as "nullable",
/// stays.
String? displayText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
  return trimmed;
}

extension DisplayText on String? {
  /// Whether there is anything fit to show.
  bool get isUsable => displayText(this) != null;

  /// The trimmed text, or null when there is nothing fit to show.
  String? get usable => displayText(this);

  /// The trimmed text, or [placeholder] when there is nothing fit to show.
  /// For a place that must not be empty, such as a table cell.
  String orPlaceholder([String placeholder = '–']) =>
      displayText(this) ?? placeholder;
}
