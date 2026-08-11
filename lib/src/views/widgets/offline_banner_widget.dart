import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// A bar across the top of the screen while the phone has no network.
///
/// It says one thing and asks for nothing. There is no retry button, because
/// there is nothing for the app to retry until the radio comes back, and a
/// button that cannot work is worse than no button. The audio layer reconnects
/// by itself on the first connectivity event, so the honest message is that
/// playback will resume, not that the user should do something.
///
/// This covers the offline case only. Being online but unable to reach the
/// SGPC server is a different situation with a different message, and it
/// belongs to the player rather than to a global banner, so [LiveStatusWidget]
/// carries it.
class OfflineBannerWidget extends ConsumerWidget {
  const OfflineBannerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While connectivity is still resolving, assume online. Flashing a scary
    // banner for one frame on every cold start would be worse than being a
    // few hundred milliseconds late to a real outage.
    final online = ref.watch(connectivityController).value ?? true;
    final l10n = AppLocalizations.of(context)!;
    final theme = ShadTheme.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: online
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              color: theme.colorScheme.destructive,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.wifiOff,
                      size: 16,
                      color: theme.colorScheme.destructiveForeground,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.offline_banner,
                            style: theme.textTheme.small.copyWith(
                              color: theme.colorScheme.destructiveForeground,
                            ),
                          ),
                          Text(
                            l10n.offline_banner_detail,
                            style: theme.textTheme.muted.copyWith(
                              color: theme.colorScheme.destructiveForeground
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
