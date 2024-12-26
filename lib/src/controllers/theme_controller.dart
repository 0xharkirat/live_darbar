import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends Notifier<AppThemeColor> {
  static const _themeColorKey = 'themeColor';
  @override
  AppThemeColor build() {
    _init();
    return AppThemeColor.orange;
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final colorName = prefs.getString(_themeColorKey);

    final themeColor = AppThemeColor.values.firstWhere(
      (element) => element.name == colorName,
      orElse: () => AppThemeColor.orange,
    );
    state = themeColor;
  }

  Future<void> changeTheme(AppThemeColor theme) async{
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeColorKey, theme.name);
  }
}

final themeController = NotifierProvider<ThemeController, AppThemeColor>(() {
  return ThemeController();
});
