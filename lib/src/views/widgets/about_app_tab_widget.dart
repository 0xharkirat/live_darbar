import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/views/widgets/slogan_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:live_darbar/l10n/app_localizations.dart';

class AboutAppTabWidget extends ConsumerWidget {
  const AboutAppTabWidget({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = ShadTheme.of(context);
    final version = ref.watch(appVersionProvider).value;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              l10n.about_section_heading,
              style: theme.textTheme.h3,
            ),
            const SizedBox(height: 16),
            SelectableText(l10n.about_section_p1, style: theme.textTheme.p),
            const SizedBox(height: 16),
            SelectableText(l10n.about_section_p2, style: theme.textTheme.p),
            const SizedBox(height: 16),
            ShadButton.outline(
              cursor: SystemMouseCursors.click,
              onPressed: onPressed,
              decoration: ShadDecoration(
                border: ShadBorder.all(color: theme.colorScheme.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.externalLink, size: 16),
                  const SizedBox(width: 8),
                  Text(l10n.about_section_contact),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SloganWidget(),
            const SizedBox(height: 16),
            // Nothing stands in for the version while the platform bundle is
            // being read. It lands within a frame or two, and a placeholder
            // would draw more attention to one line of small print than the
            // line deserves.
            if (version != null)
              SizedBox(
                width: double.infinity,
                child: SelectableText(
                  l10n.update_version(version),
                  style: theme.textTheme.muted,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
