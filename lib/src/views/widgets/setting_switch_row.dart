import 'package:flutter/cupertino.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// One switch row of the About group: an icon, a label, an optional line under
/// the label, and the switch.
///
/// The whole row is one target, and the switch only shows the state. A screen
/// reader gets one control that says [label] and [valueLabel].
class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.valueLabel,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;

  /// A line under the label that says what the switch does. Null for none.
  final String? detail;

  final bool value;

  /// What a screen reader says for [value], such as "On".
  final String valueLabel;

  /// Null while there is nothing to change, as before a saved choice loads.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 1,
      semanticLabel: detail == null ? label : '$label. $detail',
      semanticValue: valueLabel,
      onTap: onTap,
      child: PressFill(
        pressedColor: Palette.surfaceHigh,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Palette.gold),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppType.body),
                        if (detail != null)
                          Text(detail!, style: AppType.footnote),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // The row takes the tap, so the switch only shows it.
                  IgnorePointer(
                    child: CupertinoSwitch(
                      value: value,
                      onChanged: (_) {},
                      activeTrackColor: Palette.gold,
                      inactiveTrackColor: Palette.border,
                      thumbColor: Palette.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The message under a switch row, for a switch that turned on and could not
/// work: the phone blocks notifications, or it refused to set them.
///
/// Indented to the label, like the hairlines of the group.
class SettingHint extends StatelessWidget {
  const SettingHint({super.key, required this.text, this.isError = false});

  final String text;

  /// Red, for a failure the listener cannot fix in the phone's settings.
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(52, 2, 16, 14),
      child: Text(
        text,
        style: AppType.footnote.copyWith(
          color: isError ? Palette.danger : Palette.muted,
        ),
      ),
    );
  }
}
