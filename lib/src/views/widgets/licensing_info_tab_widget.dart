
import 'package:flutter/material.dart';
import 'package:live_darbar/src/views/widgets/slogan_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LicensingInfoTabWidget extends StatelessWidget {
  const LicensingInfoTabWidget({super.key});

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
            SelectableText(
              AppLocalizations.of(context)!.licensing_heading,
              style: ShadTheme.of(context).textTheme.h3,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  AppLocalizations.of(context)!.licensing_link1_title,
                  style: ShadTheme.of(context).textTheme.p,
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _launchUrl(
                        'https://www.sgpc.net/',
                      );
                    },
                    mouseCursor: SystemMouseCursors.click,
                    child: SelectableText(
                      AppLocalizations.of(context)!.licensing_link1_text,
                      style: ShadTheme.of(context).textTheme.p.copyWith(
                            decoration: TextDecoration.underline,
                            color: ShadTheme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  AppLocalizations.of(context)!.licensing_link2_title,
                  style: ShadTheme.of(context).textTheme.p,
                ),
                Expanded(
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => _launchUrl(
                      'https://www.flaticon.com/free-icons/punjab',
                    ),
                    child: SelectableText(
                      AppLocalizations.of(context)!.licensing_link2_text,
                      style: ShadTheme.of(context).textTheme.p.copyWith(
                            decoration: TextDecoration.underline,
                            color: ShadTheme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  AppLocalizations.of(context)!.licensing_link3_title,
                  style: ShadTheme.of(context).textTheme.p,
                ),
                Expanded(
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () => _launchUrl(
                      'https://artofpunjab.com/',
                    ),
                    child: SelectableText(
                      AppLocalizations.of(context)!.licensing_link3_text,
                      style: ShadTheme.of(context).textTheme.p.copyWith(
                            decoration: TextDecoration.underline,
                            color: ShadTheme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(
              AppLocalizations.of(context)!.licensing_fianl_p,
              style: ShadTheme.of(context).textTheme.p,
            ),

            const SizedBox(height: 16),
            const SloganWidget(),
          ],
        ),
      ),
    );
  }
}
