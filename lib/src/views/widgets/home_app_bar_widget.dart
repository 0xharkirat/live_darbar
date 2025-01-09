import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/views/widgets/download_button_widget.dart';
import 'package:live_darbar/src/views/widgets/info_dialog_widget.dart';
import 'package:live_darbar/src/views/widgets/theme_switch_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HomeAppBarWidget extends ConsumerWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  const HomeAppBarWidget({
    super.key,
  });

  @override
  AppBar build(BuildContext context, WidgetRef ref) {
    return AppBar(
      leading: IconButton(
          tooltip: AppLocalizations.of(context)!.language_tooltip,
          onPressed: () {
            ref.read(localeController.notifier).toggleLocale();
          },
          icon: const Icon(LucideIcons.languages)),
      title: Text(
        AppLocalizations.of(context)!.app_title,
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: [
        const ThemeSwitchWidget(),
        // if web or wasm, show this buttn
        if (kIsWeb || kIsWasm) const DownloadButtonWidget(),
    
        IconButton(
            tooltip: AppLocalizations.of(context)!.refresh_tooltip,
            onPressed: () {
              ref.read(audioController).stop();
            },
            icon: const Icon(LucideIcons.rotateCcw)),
        IconButton(
          tooltip: AppLocalizations.of(context)!.about_tooltip,
          icon: const Icon(LucideIcons.info),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return const InfoDialogWidget();
              },
            );
          },
        ),
      ],
    );
  }
}
