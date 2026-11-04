import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/widget_placement_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/widget_steps_sheet.dart';

/// The permanent "Home screen widget" row of the About group.
///
/// It does what the card on Home does: a tap adds the widget, or opens the
/// steps where the app has no way to add it. When the widget is on the home
/// screen the row says "Added" and does nothing, so a listener cannot pin a
/// second one by habit.
///
/// The About screen shows it only where the platform has home screen widgets.
class WidgetSetting extends ConsumerStatefulWidget {
  const WidgetSetting({super.key});

  @override
  ConsumerState<WidgetSetting> createState() => _WidgetSettingState();
}

class _WidgetSettingState extends ConsumerState<WidgetSetting> {
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    // Whatever Home last learned, the listener may have added the widget since.
    unawaited(ref.read(widgetPlacementProvider.notifier).refresh());
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
    final l10n = AppLocalizations.of(context)!;
    final added = ref.watch(widgetPlacementProvider) == WidgetPlacement.added;

    return Pressable(
      scale: 1,
      semanticLabel:
          '${l10n.widget_setting_title}. ${l10n.widget_setting_detail}',
      semanticValue: added ? l10n.widget_setting_added : null,
      // Until the phone has answered, a tap still works: it is how a listener
      // gets the widget on a phone that cannot say whether it is there.
      onTap: added || _adding ? null : _add,
      child: PressFill(
        pressedColor: Palette.surfaceHigh,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.square_grid_2x2,
                    size: 20,
                    color: Palette.gold,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.widget_setting_title, style: AppType.body),
                        Text(
                          l10n.widget_setting_detail,
                          style: AppType.footnote,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (added) ...[
                    const Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 18,
                      color: Palette.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.widget_setting_added,
                      style: AppType.callout.copyWith(color: Palette.muted),
                    ),
                  ] else ...[
                    Text(
                      l10n.widget_setting_add,
                      style: AppType.callout.copyWith(color: Palette.gold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 15,
                      color: Palette.faint,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
