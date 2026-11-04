import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/widget_card_controller.dart';
import 'package:live_darbar/src/controllers/widget_placement_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';
import 'package:live_darbar/src/views/widgets/widget_picture.dart';
import 'package:live_darbar/src/views/widgets/widget_steps_sheet.dart';

/// The 1 small card on Home that offers the home screen widget.
///
/// It sits under the Hukamnama card, so the order above it stays: live kirtan,
/// the Hukamnama, then reading it. It shows once, on a later visit after the
/// listener has played the Hukamnama recording, and never while a sheet is open
/// or when the widget is already on the home screen. [shouldShowWidgetCard]
/// holds every rule. About keeps a row for the listener who wants the widget
/// later.
///
/// This widget is always in the tree, with nothing visible: it asks the
/// controller to start, and tells it when the app comes back to the front, so
/// the card goes away after the listener adds the widget.
class WidgetCard extends ConsumerStatefulWidget {
  const WidgetCard({super.key});

  @override
  ConsumerState<WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends ConsumerState<WidgetCard> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => unawaited(ref.read(widgetCardProvider.notifier).resumed()),
  );

  /// Held while the phone's own dialog may be open, so a second tap cannot
  /// ask twice.
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    unawaited(ref.read(widgetCardProvider.notifier).start());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await addWidget(context, ref);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(widgetInstallProvider).isSupported;
    final card = ref.watch(widgetCardProvider).value;
    final placement = ref.watch(widgetPlacementProvider);
    // A sheet or a page over Home makes Home's route not the current one.
    final sheetOpen = !(ModalRoute.of(context)?.isCurrent ?? true);

    final show = card != null &&
        shouldShowWidgetCard(
          card.facts(
            supported: supported,
            placement: placement,
            sheetOpen: sheetOpen,
          ),
        );

    // Saved the moment the card appears, so it shows once whatever the
    // listener does next. See WidgetCardController.markShown.
    if (show && !card.showing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(widgetCardProvider.notifier).markShown());
      });
    }

    return AnimatedSize(
      // The card arrives and leaves under the things above it, so nothing
      // moves but the footer. Reduce Motion: Flutter runs this at 5% of its
      // length.
      duration: Motion.quick,
      curve: Motion.easeOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.quick,
        switchInCurve: Motion.easeOut,
        switchOutCurve: Motion.easeOut,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: show
            ? _Card(
                key: const ValueKey('widget-card'),
                onAdd: _adding ? null : _add,
                onDismiss: () =>
                    unawaited(ref.read(widgetCardProvider.notifier).dismiss()),
              )
            : const SizedBox(key: ValueKey('no-card'), width: double.infinity),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.onAdd, required this.onDismiss});

  final VoidCallback? onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Palette.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Palette.border),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const WidgetPicture(width: 132),
                  const SizedBox(width: 16),
                  Expanded(
                    child:
                        Text(l10n.widget_card_title, style: AppType.headline),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: GoldSheetButton(
                      label: l10n.widget_card_add,
                      onTap: onAdd,
                      height: 44,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: QuietSheetButton(
                      label: l10n.widget_card_dismiss,
                      onTap: onDismiss,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
