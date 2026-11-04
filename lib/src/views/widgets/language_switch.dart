import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';

/// Both languages, each written in its own script, so a reader of either can
/// find their own. An icon that toggles would name neither.
///
/// It grows with the listener's text size. A page that holds it asks
/// [widthOf] how wide it has become, and moves it to its own line when it no
/// longer fits beside its neighbour.
class LanguageSwitch extends ConsumerWidget {
  const LanguageSwitch({super.key});

  static const _languages = {'en': 'English', 'pa': 'ਪੰਜਾਬੀ'};

  /// The height of an option at the default text size. It grows from there.
  static const _optionHeight = 34.0;
  static const _optionPadding = 12.0;
  static const _framePadding = 3.0;

  static TextStyle _style({required bool active}) => AppType.footnote.copyWith(
        color: active ? Palette.foreground : Palette.muted,
        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      );

  /// How wide the switch is at the listener's text size.
  ///
  /// It measures the bold label of each language, the wider of the two
  /// weights, so the width is the same whichever language is chosen and a
  /// tap does not move a page that lays itself out by this.
  static double widthOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var width = 2 * (_framePadding + 1);
    for (final label in _languages.values) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: _style(active: true)),
        textDirection: textDirection,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      width += 2 * _optionPadding + painter.width;
      painter.dispose();
    }
    return width;
  }

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
              : () {
                  // A tick for a choice made, on the same frame as the change.
                  HapticFeedback.selectionClick();
                  ref.read(localeController.notifier).toggleLocale();
                },
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.easeOut,
            constraints: const BoxConstraints(minHeight: _optionHeight),
            padding: const EdgeInsets.symmetric(horizontal: _optionPadding),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: active ? Palette.surfaceHigh : Colors.transparent,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(label, style: _style(active: active)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(_framePadding),
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: Palette.border),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final language in _languages.entries)
            option(language.key, language.value),
        ],
      ),
    );
  }
}
