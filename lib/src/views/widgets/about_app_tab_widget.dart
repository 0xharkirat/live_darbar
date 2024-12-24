import 'package:flutter/material.dart';
import 'package:live_darbar/src/views/widgets/slogan_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AboutAppTabWidget extends StatelessWidget {
  const AboutAppTabWidget({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              AppLocalizations.of(context)!.about_section_heading,
              style: ShadTheme.of(context).textTheme.h3,
            ),
            const SizedBox(height: 16),
            SelectableText(AppLocalizations.of(context)!.about_section_p1,
                style: ShadTheme.of(context).textTheme.p),
            const SizedBox(height: 16),
            SelectableText(AppLocalizations.of(context)!.about_section_p2,
                style: ShadTheme.of(context).textTheme.p),
            const SizedBox(height: 16),
            SelectableText(AppLocalizations.of(context)!.about_section_p3,
                style: ShadTheme.of(context).textTheme.p),
            const SizedBox(height: 16),
            ShadButton.outline(
              icon: const Icon(LucideIcons.externalLink),
              cursor: SystemMouseCursors.click,
              onPressed: onPressed,
              child: SelectableText(
                AppLocalizations.of(context)!.about_section_contact,
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
