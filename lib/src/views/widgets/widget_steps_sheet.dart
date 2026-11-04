import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/widget_placement_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
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

class WidgetStepsSheet extends ConsumerWidget {
  const WidgetStepsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.widget_steps_title, style: AppType.title2),
        const SizedBox(height: 12),
        for (final (i, step) in steps.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          _Step(
            number: readerNumber(i + 1, punjabi: punjabi),
            text: step,
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

/// A step: a number in a gold circle, and the words.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

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
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.gold.withValues(alpha: 0.14),
              ),
              child: Text(
                number,
                style: AppType.callout.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
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
