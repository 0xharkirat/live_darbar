import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/mukhwak_controller.dart';
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
            data: (filePath) {
              if (filePath != null) {
                return SfPdfViewer.file(File(filePath));
              } else {
                // Trigger fetch if null (should have been triggered by main, but safe fallback)
                // Or actually, main triggers it, so we might start in loading.
                // If builds returns null but fetch didn't start, we might show loading and fetch.
                // But since we control it, let's assume if it is null, we can try network as fallback or just show loading/error.
                // Better: use network as fallback if cache fails completely, but cache logic handles it.
                // For now, let's retry fetch if data is null? Or just show network version while fetching?
                // Simple approach: show loading if null, as main triggers fetch.
                // If it persists null, maybe show network.
                // Let's rely on controller. If data is present, use file.
                // If null returned by build, wait for fetchAndCache to update it.
                // Actually, if build returns null, it means not in cache. FetchAndCache puts it into loading state?
                // No, fetchAndCache sets state = loading, then data.
                // So if we see null data, it might mean checkCache failed (cache empty) and fetch hasn't updated state yet.
                // The best way is: if data is null, we show loading indicator and let the background fetch do its job.
                // If it takes too long, users might be confused.
                // Let's implement a fallback: if null, show loading.
                return const Center(child: CircularProgressIndicator());
              }
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ),
    );
  }
}
