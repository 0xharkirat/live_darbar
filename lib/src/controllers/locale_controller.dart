import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LocaleType {
  en,
  pa,
}

class LocaleController extends Notifier<String> {
  static const _localeKey = 'locale';
  @override
  String build() {
    _init();
    return LocaleType.en.name;
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString(_localeKey);

    state = locale ?? LocaleType.en.name;
  }

  Future<void> changeLocale(String locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale);
  }

  // create toggle function
  void toggleLocale() {
    if (state == LocaleType.en.name) {
      changeLocale(LocaleType.pa.name);
    } else {
      changeLocale(LocaleType.en.name);
    }
  }
}

final localeController = NotifierProvider<LocaleController, String>(() {
  return LocaleController();
});