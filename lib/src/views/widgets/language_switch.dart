import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';

/// Both languages, each written in its own script, so a reader of either can
/// find their own. An icon that toggles would name neither.
class LanguageSwitch extends ConsumerWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeController);
    final l10n = AppLocalizations.of(context)!;

    Widget option(String code, String label) {
      final active = locale == code;
      return Semantics(
        selected: active,
        button: true,
        label: '${l10n.language_tooltip}: $label',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: active
              ? null
              : () => ref.read(localeController.notifier).toggleLocale(),
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.easeOut,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: active ? Palette.surfaceHigh : Colors.transparent,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              label,
              style: AppType.footnote.copyWith(
                color: active ? Palette.foreground : Palette.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: Palette.border),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('en', 'English'), option('pa', 'ਪੰਜਾਬੀ')],
      ),
    );
  }
}
