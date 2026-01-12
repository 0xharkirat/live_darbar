import 'package:flutter/material.dart';

import 'package:live_darbar/src/views/widgets/moving_gradient_widget.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:live_darbar/l10n/app_localizations.dart';

class MukhwakPdfViewer extends StatelessWidget {
  const MukhwakPdfViewer({super.key});

  @override
  Widget build(BuildContext context) {
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
          child: SfPdfViewer.network(
            'https://hs.sgpc.net/hukamnamapdf.php',
          ),
        ),
      ),
    );
  }
}
