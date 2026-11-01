import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/mukhwak_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/mukhwak_document.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// SGPC's own PDF of today's Hukamnama, exactly as they publish it.
class MukhwakPdfViewer extends ConsumerWidget {
  const MukhwakPdfViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(mukhwakController);

    return CupertinoPageScaffold(
      backgroundColor: Palette.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.mukhwak_pdf_title, style: AppType.headline),
        previousPageTitle: l10n.app_title,
        backgroundColor: Palette.background.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: Palette.border)),
      ),
      child: SafeArea(
        child: state.when(
          data: (document) => document != null
              ? _Document(document: document)
              : const Center(child: CupertinoActivityIndicator()),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (_, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.doc_text,
                    size: 32,
                    color: Palette.faint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.mukhwak_load_failed,
                    textAlign: TextAlign.center,
                    style: AppType.callout,
                  ),
                  const SizedBox(height: 8),
                  CupertinoButton(
                    onPressed: () =>
                        ref.read(mukhwakController.notifier).fetchAndCache(),
                    child: Text(
                      l10n.retry,
                      style: AppType.callout.copyWith(color: Palette.gold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Document extends StatelessWidget {
  const _Document({required this.document});

  final MukhwakDocument document;

  @override
  Widget build(BuildContext context) {
    final viewer = SfPdfViewer.file(
      File(document.filePath),
      // The PDF comes from a third-party server. A link inside it must not be
      // able to send the reader anywhere.
      enableHyperlinkNavigation: false,
      canShowScrollHead: false,
      pageSpacing: 8,
    );
    if (!document.isStale) return viewer;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Palette.surfaceHigh,
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.calendar,
                size: 16,
                color: Palette.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.mukhwak_from_yesterday,
                  style: AppType.footnote,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: viewer),
      ],
    );
  }
}
