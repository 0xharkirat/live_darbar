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
            // A null path means the cache was empty and the fetch started by
            // main.dart has not landed yet, so it reads the same as loading.
            data: (filePath) => filePath != null
                ? SfPdfViewer.file(File(filePath))
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
