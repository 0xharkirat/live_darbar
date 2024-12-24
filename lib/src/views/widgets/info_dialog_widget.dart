import 'package:flutter/material.dart';
import 'package:live_darbar/src/views/widgets/about_app_tab_widget.dart';
import 'package:live_darbar/src/views/widgets/about_me_tab_widget.dart';
import 'package:live_darbar/src/views/widgets/licensing_info_tab_widget.dart';
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
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.x),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            title:  SelectableText(AppLocalizations.of(context)!.information),
            backgroundColor: ShadTheme.of(context).colorScheme.accent,
            bottom:  TabBar(
              tabs: [
                Tab(text: AppLocalizations.of(context)!.about_section_heading),
                Tab(text: AppLocalizations.of(context)!.about_me_heading),
                Tab(text: AppLocalizations.of(context)!.licensing_heading),
              ],
            ),
          ),
          body: TabBarView(
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
    );
  }
}
