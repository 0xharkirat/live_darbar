import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DownloadButtonWidget extends StatelessWidget {
  const DownloadButtonWidget({super.key});

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.download),
      tooltip: AppLocalizations.of(context)!.download_tooltip,
      onSelected: (String value) {
        // handle download
        switch (value) {
          case 'android':
            _launchUrl(
                'https://play.google.com/store/apps/details?id=com.hsi.harki.live_darbar');
            break;
          case 'ios':
            _launchUrl(
                'https://apps.apple.com/us/app/live-darbar/id6449766130');
            break;
        }
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'android',
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              
              leading: Image.asset(
                'assets/images/google_play.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
              title: Text(AppLocalizations.of(context)!.google_play),
              trailing: const Icon(LucideIcons.externalLink),
            ),
          ),
          PopupMenuItem<String>(
            value: 'ios',
            child: ListTile(
              
              mouseCursor: SystemMouseCursors.click,
              leading: const Icon(Icons.apple_outlined),
              title: Text(
                AppLocalizations.of(context)!.apple_store,
              ),
              trailing: const Icon(LucideIcons.externalLink),
            ),
          ),
        ];
      },
    );
  }
}
