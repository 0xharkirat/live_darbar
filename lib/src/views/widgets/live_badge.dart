import 'package:flutter/material.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/widgets/equalizer.dart';

/// The "LIVE" mark: a red dot and the word, or moving bars once it plays.
///
/// The dot does not pulse. A slow pulse that never ends is the kind of motion
/// that bothers people, and the red already says "on air" by itself.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.playing = false, this.onImage = false});

  final bool playing;

  /// Sitting on artwork, so it gets its own dark backing for contrast.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.live.toUpperCase();
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 13,
          height: 12,
          child: Center(
            child: playing
                ? const Equalizer(active: true, color: Palette.live, height: 12)
                : const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.live,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 8),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppType.eyebrow.copyWith(color: Palette.foreground)),
      ],
    );

    if (!onImage) return content;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0xB30C0A09),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 6, 10, 6),
        child: content,
      ),
    );
  }
}
