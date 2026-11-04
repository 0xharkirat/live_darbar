import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/controllers/quality_mode_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/quality_policy.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:live_darbar/src/views/widgets/loading_ring.dart';

/// One calm line about the connection, or nothing when all is well.
///
/// Only one message shows at a time, in order of what the listener can act
/// on: a dropped stream, then yesterday's recording, then being behind live,
/// then the low-quality fallback, which shows only in Automatic mode, where
/// the app chose it. The offline case belongs to the banner at
/// the top of the screen, so this says nothing while offline.
class LiveStatusLine extends ConsumerWidget {
  const LiveStatusLine({super.key, this.compact = false, this.gap = 0});

  /// One short line for the mini player, with no action link.
  final bool compact;

  /// Space under the line, only while there is a line. With nothing to say
  /// the line takes no room, and neither does its gap.
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(livePlaybackProvider).value;
    final online = ref.watch(connectivityController).value ?? true;
    final mode = ref.watch(qualityModeProvider);
    final l10n = AppLocalizations.of(context)!;
    // Read lazily, only when an action runs, so drawing this line never
    // creates the audio player.
    AudioController controller() => ref.read(audioController);

    final status =
        live == null ? null : _pick(live, online, mode, l10n, controller);

    return AnimatedSwitcher(
      duration: Motion.quick,
      switchInCurve: Motion.easeOut,
      child: status == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Padding(
              key: ValueKey(status.label),
              padding: EdgeInsets.only(bottom: gap),
              child: _Line(status: status, compact: compact),
            ),
    );
  }

  static _Status? _pick(
    LivePlaybackState live,
    bool online,
    QualityMode mode,
    AppLocalizations l10n,
    AudioController Function() controller,
  ) {
    if (live.status == LiveStatus.failed) {
      if (!online) return null;
      final givenUp = live.reconnectAttempt >= 3;
      return _Status(
        label: givenUp ? l10n.stream_unreachable : l10n.reconnecting,
        color: Palette.danger,
        icon: givenUp ? CupertinoIcons.exclamationmark_circle : null,
        spinner: !givenUp,
        action: givenUp ? l10n.retry : null,
        onAction: givenUp ? () => controller().onNetworkRestored() : null,
      );
    }
    if (live.edition?.isStale ?? false) {
      return _Status(
        label: l10n.yesterdays_recording,
        color: Palette.muted,
        icon: CupertinoIcons.calendar,
      );
    }
    if (live.isBehindLive) {
      return _Status(
        label: l10n.behind_live(live.minutesBehind),
        color: Palette.muted,
        icon: CupertinoIcons.clock,
        action: l10n.go_live,
        onAction: () => controller().skipToLive(),
      );
    }
    // Only a drop the app made on its own is news. Someone who chose Data
    // saver already knows the stream is low, and the player says so beside
    // the LIVE badge.
    if (live.isLiveSource &&
        live.quality == StreamQuality.low &&
        mode == QualityMode.automatic &&
        !StreamQuality.isWeb) {
      return _Status(
        label: l10n.low_quality_stream,
        color: Palette.muted,
        icon: CupertinoIcons.antenna_radiowaves_left_right,
      );
    }
    return null;
  }
}

class _Status {
  const _Status({
    required this.label,
    required this.color,
    this.icon,
    this.spinner = false,
    this.action,
    this.onAction,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool spinner;
  final String? action;
  final VoidCallback? onAction;
}

class _Line extends StatelessWidget {
  const _Line({required this.status, required this.compact});

  final _Status status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = AppType.footnote.copyWith(color: status.color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status.spinner)
          // The words beside it say what is happening.
          LoadingRing(size: 12, color: status.color, announce: false)
        else if (status.icon != null)
          Icon(status.icon, size: 14, color: status.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            status.label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!compact && status.action != null) ...[
          const SizedBox(width: 4),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 44),
            onPressed: status.onAction,
            child: Text(
              status.action!,
              style: AppType.footnote.copyWith(
                color: Palette.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
