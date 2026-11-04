import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/maintenance_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';

/// A calm note at the top of every screen while `release.json` carries a
/// maintenance message.
///
/// It says what the maintainer wrote, in the listener's language, and gets out
/// of the way: the app keeps playing what it can, and nothing is blocked or
/// covered. It looks like the offline banner and sits under it, above every
/// route, so it reaches the player and the reader too.
class MaintenanceBanner extends ConsumerWidget {
  const MaintenanceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenance = ref.watch(maintenanceProvider).value;
    final locale = ref.watch(localeController);
    // The offline banner, when it shows, is above this and has taken the room
    // for the status bar.
    final offline = !(ref.watch(connectivityController).value ?? true);

    return AnimatedSize(
      duration: Motion.standard,
      curve: Motion.easeOut,
      alignment: Alignment.topCenter,
      child: maintenance == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: Palette.surfaceHigh,
              child: SafeArea(
                top: !offline,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          CupertinoIcons.wrench,
                          size: 18,
                          color: Palette.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          maintenance.messageFor(locale),
                          style: AppType.footnote.copyWith(
                            color: Palette.foreground,
                          ),
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
