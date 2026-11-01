import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';

/// A calm note at the top of every screen while the phone is offline.
///
/// Losing signal on a train is expected, so this is a quiet surface-coloured
/// strip with the reassurance first, not an alarm-red bar. It sits above every
/// route, so it reaches the player and the reader too.
class OfflineBannerWidget extends ConsumerWidget {
  const OfflineBannerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityController).value ?? true;
    final l10n = AppLocalizations.of(context)!;

    return AnimatedSize(
      duration: Motion.standard,
      curve: Motion.easeOut,
      alignment: Alignment.topCenter,
      child: online
          ? const SizedBox(width: double.infinity)
          : Material(
              color: Palette.surfaceHigh,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.wifi_slash,
                        size: 18,
                        color: Palette.gold,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.offline_banner,
                              style: AppType.headline.copyWith(fontSize: 15),
                            ),
                            Text(
                              l10n.offline_banner_detail,
                              style: AppType.footnote,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
