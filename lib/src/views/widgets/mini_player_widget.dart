import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/views/screens/now_playing_screen.dart';
import 'package:live_darbar/src/views/widgets/artwork.dart';
import 'package:live_darbar/src/views/widgets/equalizer.dart';
import 'package:live_darbar/src/views/widgets/live_status_widget.dart';
import 'package:live_darbar/src/views/widgets/play_button.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// The floating player, once something has played.
///
/// It rises into place the first time sound starts and then stays, even when
/// paused, so the control never disappears from under a reaching finger.
/// Before that, the home screen's own play buttons do the job and a second
/// "Live Kirtan ▶" bar would only repeat the hero card.
///
/// Tap it, or swipe it up, to open the full player.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const height = 68.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowPlayingProvider);
    final l10n = AppLocalizations.of(context)!;
    final title = switch (now.index) {
      kMukhwakIndex => l10n.mukhwak,
      kKathaIndex => l10n.mukhwak_katha,
      _ => l10n.live_kirtan,
    };
    final subtitle = now.isLive ? l10n.live_location : l10n.todays_recording;

    final bar = Pressable(
      semanticLabel: title,
      scale: 0.98,
      onTap: () => showNowPlaying(context),
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) showNowPlaying(context);
        },
        child: Container(
          height: height,
          decoration: ShapeDecoration(
            color: Palette.surfaceHigh,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Palette.border),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                  child: Row(
                    children: [
                      Artwork(index: now.index, radius: 12, width: 48, height: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (now.isPlaying) ...[
                                  Equalizer(
                                    active: true,
                                    height: 11,
                                    color: now.isLive
                                        ? Palette.live
                                        : Palette.gold,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    title,
                                    style: AppType.headline.copyWith(
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            _SubtitleOrStatus(subtitle: subtitle),
                          ],
                        ),
                      ),
                      PlayButton(
                        index: now.index,
                        size: 48,
                        look: PlayButtonLook.bare,
                      ),
                    ],
                  ),
                ),
                if (!now.isLive)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ProgressEdge(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final reduced = Motion.reduced(context);
    return IgnorePointer(
      ignoring: !now.started,
      child: AnimatedSlide(
        offset: now.started || reduced ? Offset.zero : const Offset(0, 1.4),
        duration: Motion.slow,
        curve: Motion.easeOut,
        child: AnimatedOpacity(
          opacity: now.started ? 1 : 0,
          duration: Motion.standard,
          curve: Motion.easeOut,
          child: bar,
        ),
      ),
    );
  }
}

/// The location line, replaced by the connection status when there is one,
/// so trouble shows where the eye already is.
class _SubtitleOrStatus extends ConsumerWidget {
  const _SubtitleOrStatus({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(livePlaybackProvider).value;
    final hasIssue = live != null &&
        (live.status == LiveStatus.failed || (live.edition?.isStale ?? false));

    return AnimatedSwitcher(
      duration: Motion.quick,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      child: hasIssue
          ? const LiveStatusLine(key: ValueKey('status'), compact: true)
          : Text(
              subtitle,
              key: const ValueKey('subtitle'),
              style: AppType.footnote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

/// A hairline of progress along the bottom edge, for recordings only.
class _ProgressEdge extends ConsumerWidget {
  const _ProgressEdge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(audioProgressProvider).value;
    final total = p?.totalDuration?.inMilliseconds ?? 0;
    final f = total <= 0
        ? 0.0
        : (p!.position.inMilliseconds / total).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: f,
        child: Container(height: 2, color: Palette.gold),
      ),
    );
  }
}
