

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  static ShadThemeData shadThemeData(ShadColorScheme colorScheme) {
    return ShadThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      textTheme: ShadTextTheme.fromGoogleFont(
        GoogleFonts.manrope,
      ),
    );
  }

  static ThemeData materialThemeData(ShadColorScheme colorScheme) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: colorScheme.primary, brightness: Brightness.dark),
     
      textTheme: GoogleFonts.manropeTextTheme(),
    );
  }
}

//

enum AppThemeColor {
  blue,
  green,
  orange,
  red,
  rose,
  violet,
  yellow,
}

extension AppThemeColorExtension on AppThemeColor {
  ShadColorScheme get colorScheme {
    switch (this) {
      case AppThemeColor.blue:
        return const ShadBlueColorScheme.dark();

      case AppThemeColor.green:
        return const ShadGreenColorScheme.dark();

      case AppThemeColor.orange:
        return const ShadOrangeColorScheme.dark();
      case AppThemeColor.red:
        return const ShadRedColorScheme.dark();
      case AppThemeColor.rose:
        return const ShadRoseColorScheme.dark();

      case AppThemeColor.violet:
        return const ShadVioletColorScheme.dark();
      case AppThemeColor.yellow:
        return const ShadYellowColorScheme.dark();
    }
  }

  Color get materialColor {
    return colorScheme.primary;
    
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
