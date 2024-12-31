import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/core/colors.dart';
import 'package:live_darbar/src/core/get_localized_title.dart';
import 'package:live_darbar/src/views/widgets/play_pause_button_widget.dart';
import 'package:live_darbar/src/views/widgets/progress_bar_custom.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class IndividualItemDialog extends ConsumerWidget {
  const IndividualItemDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog.fullscreen(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronDown),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Container(
          decoration:  BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1,
              colors: [
                ShadTheme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ShadTheme.of(context).colorScheme.background.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20.0,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(16.0),
                    ),
                    child: Consumer(builder: (context, ref, _) {
                      final sequenceStateAsync =
                          ref.watch(sequenceStateProvider);

                      // just get the id of the current source
                      final id = sequenceStateAsync.when<int>(
                        data: (value) {
                          if (value == null) {
                            return 0;
                          }
                          return int.parse(value.currentSource?.tag.id);
                        },
                        loading: () => 0,
                        error: (error, _) => 0,
                      );
                      return FadeInImage(
                        placeholder: MemoryImage(kTransparentImage),
                        image: AssetImage('assets/images/$id.jpg'),
                        fit: BoxFit.fitWidth,
                      );
                    }),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final sequenceStateAsync =
                          ref.watch(sequenceStateProvider);

                      final title = sequenceStateAsync.when<String>(
                        data: (sequenceState) {
                          // Extract current media item details as Source
                          final source = sequenceState?.currentSource?.tag;

                          // Fall back to default source if current source is null

                          if (source == null) {
                            return AppLocalizations.of(context)!.loading;
                          }

                          final title = source?.title;

                          return getLocalizedTitle(title, context);
                        },
                        loading: () => AppLocalizations.of(context)!.loading,
                        error: (error, _) =>
                            AppLocalizations.of(context)!.loading,
                      );
                      return Text(
                        title,
                        style: ShadTheme.of(context).textTheme.h2,
                      );
                    },
                  ),
                  ProgressBarCustom(
                    onSeek: ref.read(audioController).seek,
                  ),
                  const Center(child: PlayPauseButtonWidget()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
