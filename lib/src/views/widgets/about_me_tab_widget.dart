import 'package:flutter/material.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/open_link.dart';

class AboutMeTabWidget extends StatelessWidget {
  const AboutMeTabWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = ShadTheme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(l10n.about_me_heading, style: theme.textTheme.h3),
            const SizedBox(height: 16),
            SelectableText(l10n.about_me_p1, style: theme.textTheme.p),
            const SizedBox(height: 16),
            SelectableText(l10n.about_me_p2, style: theme.textTheme.p),
            const SizedBox(height: 16),
            // Lucide dropped its brand icons, so none of these can carry a
            // logo. The label names the destination and the icon only hints at
            // what is behind it.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LinkButton(
                  icon: LucideIcons.globe,
                  label: l10n.about_me_website,
                  url: 'https://harksingh.com',
                ),
                _LinkButton(
                  icon: LucideIcons.drum,
                  label: l10n.about_me_tabla_button,
                  url:
                      'https://www.youtube.com/watch?v=0lhJ_0ve5q8&list=PLLx2TfaNTPhyQPAIfEnib4MfXppYtYVyB',
                ),
                _LinkButton(
                  icon: LucideIcons.code,
                  label: l10n.about_me_github,
                  url: 'https://github.com/0xHARKIRAT',
                ),
                _LinkButton(
                  icon: LucideIcons.briefcase,
                  label: l10n.about_me_linkedin,
                  url: 'https://www.linkedin.com/in/talesofhark',
                ),
                _LinkButton(
                  icon: LucideIcons.circlePlay,
                  label: l10n.about_me_youtube,
                  url: 'https://www.youtube.com/@TalesofHark',
                ),
                _LinkButton(
                  icon: LucideIcons.atSign,
                  label: l10n.about_me_x,
                  url: 'https://x.com/TalesofHark',
                ),
                _LinkButton(
                  icon: LucideIcons.camera,
                  label: l10n.about_me_instagram,
                  url: 'https://www.instagram.com/talesofhark',
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: SelectableText(
                l10n.about_me_motto,
                style: theme.textTheme.muted,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      decoration: ShadDecoration(
        border: ShadBorder.all(
          color: ShadTheme.of(context).colorScheme.primary,
        ),
      ),
      cursor: SystemMouseCursors.click,
      onPressed: () => openLink(url),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
