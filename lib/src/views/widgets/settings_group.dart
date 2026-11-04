import 'package:flutter/material.dart';
import 'package:live_darbar/src/core/palette.dart';

/// An inset group, iOS Settings style: rows on one surface, hairlines between
/// them indented to the text so they read as one list.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Palette.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Palette.border),
        ),
      ),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 52),
                  child: Divider(height: 1, thickness: 1, color: Palette.border),
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
