import 'package:flutter/material.dart';
import 'package:live_darbar/src/views/widgets/about_app_tab_widget.dart';
import 'package:live_darbar/src/views/widgets/about_me_tab_widget.dart';
import 'package:live_darbar/src/views/widgets/licensing_info_tab_widget.dart';
import 'package:live_darbar/src/views/widgets/moving_gradient_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class InfoDialogWidget extends StatelessWidget {
  const InfoDialogWidget({
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
    return Dialog.fullscreen(
      child: DefaultTabController(
        length: 3,
        child: MovingGradientWidget(
          colors: [
            Theme.of(context).colorScheme.onTertiary,
            Theme.of(context).colorScheme.onPrimary,
            Theme.of(context).colorScheme.inversePrimary,
            Theme.of(context).colorScheme.onSecondary,
          ],
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              title: SelectableText(AppLocalizations.of(context)!.information),
              backgroundColor: ShadTheme.of(context)
                  .colorScheme
                  .accent
                  .withValues(alpha: 0.6),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: TabBar(
                      indicatorColor: ShadTheme.of(context).colorScheme.primary,
                      labelColor: ShadTheme.of(context).colorScheme.primary,
                      
                      tabs: [
                        Tab(
                            text: AppLocalizations.of(context)!
                                .about_section_heading),
                        Tab(
                            text:
                                AppLocalizations.of(context)!.about_me_heading),
                        Tab(
                            text: AppLocalizations.of(context)!
                                .licensing_heading),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500),
                child: TabBarView(
                  children: [
                    // About the App Tab
                    AboutAppTabWidget(
                      onPressed: () => _launchUrl(
                        'https://forms.gle/HKZtyYzdEYstgbby7',
                      ),
                    ),

                    // About Me Tab
                    const AboutMeTabWidget(),

                    // Licensing Information Tab
                    const LicensingInfoTabWidget()
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
