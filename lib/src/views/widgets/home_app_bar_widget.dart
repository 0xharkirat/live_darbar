import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/views/widgets/download_button_widget.dart';
import 'package:live_darbar/src/views/widgets/info_dialog_widget.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:live_darbar/src/views/screens/mukhwak_pdf_viewer.dart';

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
        // if web or wasm, show this buttn
        if (kIsWeb || kIsWasm) const DownloadButtonWidget(),

        // This calls stop(), and used to wear a refresh arrow labelled
        // "Refresh Audio Sources", which is not what it does. Stopping is the
        // genuinely useful function here, because pause leaves the media
        // notification sitting in the shade and this is the only way to clear
        // it, so the icon and label now match the behaviour rather than the
        // other way round. Reconnecting no longer needs a button: failures
        // retry themselves, and drifting behind live has its own affordance.
        IconButton(
            tooltip: AppLocalizations.of(context)!.stop_tooltip,
            onPressed: () {
              ref.read(audioController).stop();
            },
            icon: const Icon(LucideIcons.circleStop)),
        IconButton(
            tooltip: AppLocalizations.of(context)!.mukhwak_pdf_title,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MukhwakPdfViewer(),
                ),
              );
            },
            icon: const Icon(LucideIcons.fileText)),
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
