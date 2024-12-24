import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/theme_controller.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
      tooltip: "Change Color",
      itemBuilder: (context) {
        return AppThemeColor.values.map((themeColor) {
          return PopupMenuItem<AppThemeColor>(
              value: themeColor, child: Text(themeColor.name.capitalize()));
        }).toList();
      },
    );
  }
}
