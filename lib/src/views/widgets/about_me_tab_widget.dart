import 'package:flutter/material.dart';
import 'package:live_darbar/src/views/widgets/slogan_widget.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AboutMeTabWidget extends StatelessWidget {
  const AboutMeTabWidget({
    super.key,
  });

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(AppLocalizations.of(context)!.about_me_heading, style: ShadTheme.of(context).textTheme.h3),
            const SizedBox(height: 16),
            SelectableText(
              AppLocalizations.of(context)!.about_me_p1,
              style: ShadTheme.of(context).textTheme.p,
            ),
            const SizedBox(height: 16),
            SelectableText(
              AppLocalizations.of(context)!.about_me_p2,
              style: ShadTheme.of(context).textTheme.p,
            ),
            const SizedBox(height: 16),
            SelectableText(
              AppLocalizations.of(context)!.about_me_p3,
              style: ShadTheme.of(context).textTheme.p,
            ),
            const SizedBox(height: 16),
            ShadButton.raw(
              variant: ShadButtonVariant.link,
              icon: const Icon(LucideIcons.youtube),
              cursor: SystemMouseCursors.click,
              child: Text(
                AppLocalizations.of(context)!.about_me_tabla_button,
              ),
              onPressed: () => _launchUrl(
                'https://www.youtube.com/watch?v=0lhJ_0ve5q8&list=PLLx2TfaNTPhyQPAIfEnib4MfXppYtYVyB',
              ),
            ),
            ShadButton.raw(
              variant: ShadButtonVariant.link,
              icon: const Icon(LucideIcons.externalLink),
              cursor: SystemMouseCursors.click,
              child: Text(
                AppLocalizations.of(context)!.about_me_my_story,
              ),
              onPressed: () => _launchUrl(
                'https://openinapp.link/so8kh',
              ),
            ),
            ShadButton.raw(
              variant: ShadButtonVariant.link,
              icon: const Icon(LucideIcons.linkedin),
              cursor: SystemMouseCursors.click,
              child:  Text(
                AppLocalizations.of(context)!.about_me_linkedin,
              ),
              onPressed: () => _launchUrl(
                'https://www.linkedin.com/in/0xharkirat/',
              ),
            ),
            const SizedBox(height: 16),
            const SloganWidget(),
          ],
        ),
      ),
    );
  }
}
