/// Splits SGPC's explanation of a Hukamnama into 1 paragraph per verse.
///
/// SGPC sends the meaning as 1 block of text. Inside it, each verse's meaning
/// ends with the verse number, the way the Gurbani lines do:
///
/// - English: `|| 1 ||`, `|| Pause ||`, `|| Second Pause ||`, `|| 4 || 5 ||`
/// - Punjabi: `।੧।`, `। ਰਹਾਉ।`, `। ਰਹਾਉ ਦੂਜਾ ।`
///
/// Breaking after each marker turns a wall of text into short paragraphs that
/// line up with the verses above them, which is far easier to follow for
/// someone reading slowly. The marker stays at the end of its paragraph, with
/// its spacing tidied.
List<String> meaningParagraphs(String text) {
  final marker = RegExp(
    r'(\|\|\s*(?:\d+|Pause|Second Pause)\s*\|\|(?:\s*\d+\s*\|\|)*)'
    r'|(।\s*(?:[੦-੯]+|ਰਹਾਉ(?:\s*ਦੂਜਾ)?)\s*।(?:\s*[੦-੯]+\s*।)*)',
  );

  final paragraphs = <String>[];
  var start = 0;
  for (final match in marker.allMatches(text)) {
    final body = text.substring(start, match.start).trim();
    final end = _tidy(match.group(0)!);
    // A Gurmukhi danda sits on the word; an English marker gets a space.
    final gap = end.startsWith('|') ? ' ' : '';
    final paragraph = body.isEmpty ? end : '$body$gap$end';
    if (paragraph.trim().isNotEmpty) paragraphs.add(paragraph.trim());
    start = match.end;
  }
  final rest = text.substring(start).trim();
  if (rest.isNotEmpty) paragraphs.add(rest);
  return paragraphs.isEmpty ? [text.trim()] : paragraphs;
}

/// `||  Pause  ||` becomes `|| Pause ||`; `। ਰਹਾਉ।` becomes `।ਰਹਾਉ।`.
String _tidy(String marker) {
  if (marker.startsWith('|')) {
    return marker.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  return marker.replaceAll(RegExp(r'\s*।\s*'), '।').replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
}
