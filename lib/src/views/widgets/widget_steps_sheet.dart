import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/widget_placement_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/demo_film.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';

/// Adds the home screen widget, for the card on Home and the row in About.
///
/// Android shows its own dialog and puts the widget on the home screen if the
/// listener agrees. Where the app has nothing to ask (an iPhone has no call
/// for it, and some Android launchers cannot pin), the steps open as a sheet.
Future<void> addWidget(BuildContext context, WidgetRef ref) async {
  final asked = await ref.read(widgetPlacementProvider.notifier).add();
  if (!asked && context.mounted) await showWidgetStepsSheet(context);
}

/// The width of the film's phone frame. It is tall (about 360 points), so it
/// stays narrow, and the 3 steps stay in view on a phone.
const _filmWidth = 172.0;

/// The steps to add the widget by hand: a short film above the 3 steps. An
/// iPhone sees an iPhone do it, and an Android phone sees a launcher do it.
Future<void> showWidgetStepsSheet(BuildContext context) =>
    showAppSheet<void>(context, (_) => const WidgetStepsSheet());

class WidgetStepsSheet extends ConsumerStatefulWidget {
  const WidgetStepsSheet({super.key});

  @override
  ConsumerState<WidgetStepsSheet> createState() => _WidgetStepsSheetState();
}

class _WidgetStepsSheetState extends ConsumerState<WidgetStepsSheet> {
  /// The step the film shows now, whose number is lit. Hark, 6 November: the
  /// film and the numbered list belong together, so the number of the step on
  /// screen fills in, quietly.
  int? _onScreen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final punjabi = Localizations.localeOf(context).languageCode == 'pa';
    final iphone = ref.watch(widgetInstallProvider).isIphone;

    final steps = [
      l10n.widget_steps_press_hold,
      if (iphone) ...[
        l10n.widget_steps_iphone_add,
        l10n.widget_steps_iphone_find,
      ] else ...[
        l10n.widget_steps_android_widgets,
        l10n.widget_steps_android_find,
      ],
    ];

    return SheetFrame(
      children: [
        Center(
          child: DemoFilmView(
            film: iphone ? DemoFilm.iphone : DemoFilm.android,
            width: _filmWidth,
            onStep: (step) {
              if (mounted) setState(() => _onScreen = step);
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.widget_steps_title, style: AppType.title2),
        const SizedBox(height: 12),
        for (final (i, step) in steps.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _Step(
            key: ValueKey('widget-step-$i'),
            number: readerNumber(i + 1, punjabi: punjabi),
            text: step,
            lit: _onScreen == i,
          ),
        ],
        const SizedBox(height: 24),
        GoldSheetButton(
          label: l10n.widget_steps_done,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// A step: a number in a gold circle, and the words. While the film shows the
/// step, the circle fills with gold.
class _Step extends StatelessWidget {
  const _Step({
    super.key,
    required this.number,
    required this.text,
    required this.lit,
  });

  final String number;
  final String text;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    // The reader hears "1. Press and hold...", once.
    return Semantics(
      container: true,
      label: '$number. $text',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A colour change only, so nothing moves while the listener
            // reads, and it eases as the film moves on.
            AnimatedContainer(
              duration: Motion.standard,
              curve: Motion.easeOut,
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    lit ? Palette.gold : Palette.gold.withValues(alpha: 0.14),
              ),
              child: AnimatedDefaultTextStyle(
                duration: Motion.standard,
                curve: Motion.easeOut,
                style: AppType.callout.copyWith(
                  color: lit ? Palette.onGold : Palette.gold,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
                child: Text(number),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                // The first line of text sits level with the circle's middle.
                padding: const EdgeInsets.only(top: 2),
                child: Text(text, style: AppType.body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
