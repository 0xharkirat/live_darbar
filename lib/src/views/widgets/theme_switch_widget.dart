import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/theme_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ThemeSwitchWidget extends ConsumerWidget {
  const ThemeSwitchWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.watch(themeController.notifier);

    return PopupMenuButton<AppThemeColor>(
      icon: const Icon(LucideIcons.palette),
      onSelected: (themeColor) {
        themeNotifier.changeTheme(themeColor);
      },
      initialValue: ref.watch(themeController),
      tooltip: AppLocalizations.of(context)!.color_tooltip,
      itemBuilder: (context) {
        return AppThemeColor.values.map((themeColor) {
          return PopupMenuItem<AppThemeColor>(
              value: themeColor, child: Text(getLocalizedTitle(themeColor, context)));
        }).toList();
      },
    );
  }
}

// create a function to return the localized theme colors
String getLocalizedTitle(AppThemeColor themeColor, BuildContext context) {
  final localizations = AppLocalizations.of(context)!;
  switch (themeColor) {
    case AppThemeColor.blue:
      return localizations.blue;
    case AppThemeColor.green:
      return localizations.green;
    case AppThemeColor.violet:
      return localizations.purple;
    case AppThemeColor.red:
      return localizations.red;
    case AppThemeColor.orange:
      return localizations.orange;
    case AppThemeColor.yellow:
      return localizations.yellow;
    case AppThemeColor.rose:
      return localizations.rose;
  }
}


