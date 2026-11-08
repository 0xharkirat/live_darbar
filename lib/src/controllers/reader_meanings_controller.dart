import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which meanings the Hukamnama reader shows under each line.
@immutable
class ReaderMeanings {
  const ReaderMeanings({this.punjabi = true, this.english = true});

  /// Prof. Sahib Singh's Punjabi meaning.
  final bool punjabi;

  /// Dr. Sant Singh Khalsa's English meaning.
  final bool english;

  ReaderMeanings copyWith({bool? punjabi, bool? english}) => ReaderMeanings(
        punjabi: punjabi ?? this.punjabi,
        english: english ?? this.english,
      );

  @override
  bool operator ==(Object other) =>
      other is ReaderMeanings &&
      other.punjabi == punjabi &&
      other.english == english;

  @override
  int get hashCode => Object.hash(punjabi, english);
}

/// The listener's choice of meanings under each line, remembered between
/// visits.
///
/// Both show by default, Punjabi first: Hark, 7 November, "punjabi meaning as
/// well line by line". The listener can turn either off, or both, to read the
/// Gurbani alone.
class ReaderMeaningsController extends Notifier<ReaderMeanings> {
  static const _punjabiKey = 'reader_meaning_punjabi';
  static const _englishKey = 'reader_meaning_english';

  /// Set once the listener changes a meaning, so a slow read of the saved
  /// choice does not undo the change.
  bool _changed = false;

  @override
  ReaderMeanings build() {
    _load();
    return const ReaderMeanings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_changed || !ref.mounted) return;
    state = ReaderMeanings(
      punjabi: prefs.getBool(_punjabiKey) ?? true,
      english: prefs.getBool(_englishKey) ?? true,
    );
  }

  Future<void> setPunjabi(bool on) => _save(state.copyWith(punjabi: on));

  Future<void> setEnglish(bool on) => _save(state.copyWith(english: on));

  Future<void> _save(ReaderMeanings next) async {
    _changed = true;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_punjabiKey, next.punjabi);
    await prefs.setBool(_englishKey, next.english);
  }
}

final readerMeaningsProvider =
    NotifierProvider<ReaderMeaningsController, ReaderMeanings>(
  ReaderMeaningsController.new,
);
