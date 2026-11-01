import 'package:flutter/material.dart';

import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/open_link.dart';

class LicensingInfoTabWidget extends StatelessWidget {
  const LicensingInfoTabWidget({super.key});

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
            SelectableText(
              l10n.licensing_heading,
              style: theme.textTheme.h3,
            ),
            const SizedBox(height: 16),
            _Attribution(
              source: l10n.licensing_audio_source,
              text: l10n.licensing_audio,
              url: 'https://www.sgpc.net/',
            ),
            const SizedBox(height: 16),
            _Attribution(
              source: l10n.licensing_logo_source,
              text: l10n.licensing_logo,
              url: 'https://www.flaticon.com/free-icons/punjab',
            ),
            const SizedBox(height: 16),
            _Attribution(
              source: l10n.licensing_images_source,
              text: l10n.licensing_images,
              url: 'https://artofpunjab.com/',
            ),
            const SizedBox(height: 16),
            SelectableText(
              l10n.licensing_final_p,
              style: theme.textTheme.p,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// One credit: who the work belongs to, then what was taken.
///
/// The name sits on its own line and is the only tappable part. Underlining a
/// whole sentence, which is what this screen used to do, reads as three links
/// rather than three credits, and hides where the tap actually goes.
class _Attribution extends StatelessWidget {
  const _Attribution({
    required this.source,
    required this.text,
    required this.url,
  });

  final String source;
  final String text;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () => openLink(url),
          child: Text(
            source,
            style: theme.textTheme.p.copyWith(
              decoration: TextDecoration.underline,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(text, style: theme.textTheme.muted),
      ],
    );
  }
}
