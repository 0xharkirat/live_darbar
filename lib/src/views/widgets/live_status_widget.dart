import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/models/live_playback_state.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Tells the listener what the player is doing when it is not simply working,
/// and offers the one action that helps.
///
/// It renders nothing in the ordinary case. Four things are worth interrupting
/// for: the connection dropped and we are retrying, the recording loaded is
/// not the day the listener asked for, we fell back to the low bitrate tier,
/// or a long pause has left the playhead well behind the broadcast. Anything
/// less and a badge would be noise.
class LiveStatusWidget extends ConsumerWidget {
  const LiveStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(livePlaybackProvider).value;
    if (live == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = ShadTheme.of(context);

    if (live.status == LiveStatus.failed) {
      // Say nothing here when the phone itself is offline. The banner across
      // the top already covers that, and repeating it in the player would
      // imply two separate problems.
      final online = ref.watch(connectivityController).value ?? true;
      if (!online) return const SizedBox.shrink();

      // A failure always has a retry already scheduled, so the honest label is
      // "reconnecting", not "failed". Only name it once enough attempts have
      // gone by that the listener deserves to know it is not just a blip, and
      // then name it accurately: we are online, so it is the stream that is
      // unreachable, not the connection that is lost.
      final givenUp = live.reconnectAttempt >= 3;
      return _Chip(
        color: theme.colorScheme.destructive,
        icon: givenUp ? LucideIcons.circleAlert : null,
        showSpinner: !givenUp,
        label: givenUp ? l10n.stream_unreachable : l10n.reconnecting,
        action: givenUp ? l10n.retry : null,
        onAction:
            givenUp ? () => ref.read(audioController).onNetworkRestored() : null,
      );
    }

    // SGPC uploads the Hukamnama around half past five in the morning in
    // Amritsar and the Katha around half past nine, so for a good part of
    // every day the app is serving the previous day's recording because that
    // is all there is. Playing it is right; playing it silently is not, since
    // the shabad would not match the one being read at Darbar Sahib and the
    // listener would have no way to tell why.
    //
    // Only the previous day earns a chip. Content from the undated endpoint is
    // always the newest SGPC holds, so there is nothing true to say about it.
    if (live.edition?.isStale ?? false) {
      return _Chip(
        color: theme.colorScheme.mutedForeground,
        icon: LucideIcons.calendarClock,
        label: l10n.yesterdays_recording,
      );
    }

    if (live.isBehindLive) {
      return _Chip(
        color: theme.colorScheme.primary,
        icon: LucideIcons.radio,
        label: l10n.behind_live(live.behindLive.inSeconds),
        action: l10n.go_live,
        onAction: () => ref.read(audioController).skipToLive(),
      );
    }

    if (live.isLiveSource &&
        live.quality == StreamQuality.low &&
        !StreamQuality.isWeb) {
      // Only worth saying off web. On web the low tier is the only one there
      // is, so calling it a downgrade would be misleading.
      return _Chip(
        color: theme.colorScheme.mutedForeground,
        icon: LucideIcons.signalLow,
        label: l10n.low_quality_stream,
      );
    }

    return const SizedBox.shrink();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.color,
    required this.label,
    this.icon,
    this.showSpinner = false,
    this.action,
    this.onAction,
  });

  final Color color;
  final String label;
  final IconData? icon;
  final bool showSpinner;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSpinner)
          SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
          )
        else if (icon != null)
          Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.muted.copyWith(color: color),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          ShadButton.link(
            padding: EdgeInsets.zero,
            onPressed: onAction,
            child: Text(action!, style: theme.textTheme.small),
          ),
        ],
      ],
    );
  }
}
