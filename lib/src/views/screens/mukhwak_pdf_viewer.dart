import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/mukhwak_controller.dart';
import 'package:live_darbar/src/models/mukhwak_document.dart';
import 'package:live_darbar/src/views/widgets/moving_gradient_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:live_darbar/l10n/app_localizations.dart';

class MukhwakPdfViewer extends ConsumerWidget {
  const MukhwakPdfViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mukhwakState = ref.watch(mukhwakController);

    return MovingGradientWidget(
      colors: [
        Theme.of(context).colorScheme.onTertiary,
        Theme.of(context).colorScheme.onPrimary,
        Theme.of(context).colorScheme.inversePrimary,
        Theme.of(context).colorScheme.onSecondary,
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.mukhwak_pdf_title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: ShadButton.ghost(
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(LucideIcons.chevronLeft),
          ),
        ),
        body: SafeArea(
          child: mukhwakState.when(
            // A null document means the cache was empty and the fetch started
            // by main.dart has not landed yet, so it reads the same as
            // loading. Unlike before, that state now ends: every request in
            // MukhwakController carries a deadline, so a stalled endpoint
            // resolves into the error branch rather than spinning forever.
            data: (document) => document != null
                ? _Document(document: document)
                : const Center(child: CircularProgressIndicator()),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.of(context)!.mukhwak_load_failed,
                  textAlign: TextAlign.center,
                  style: ShadTheme.of(context).textTheme.muted,
                ),
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
      enableHyperlinkNavigation: false,
    );
    if (!document.isStale) return viewer;

    // Named rather than merely shown, for the same reason the player says it.
    // The Mukhwak is dated content read on one particular morning, and someone
    // reading the wrong day's without being told has been misled rather than
    // merely inconvenienced.
    return Column(
      children: [
        const _StaleBanner(),
        Expanded(child: viewer),
      ],
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.muted,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.calendarClock,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.mukhwak_from_yesterday,
              style: theme.textTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}
