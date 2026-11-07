import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/youtube_live_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/youtube_live.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

/// The Home row "Watch live on YouTube", under live kirtan.
///
/// SGPC streams video of Sri Harmandir Sahib on YouTube about 3 times a day,
/// and an audio-only stream beside it. The row follows the answer that a
/// GitHub Action checks every 5 minutes ([youtubeLiveProvider]): it shows for
/// a kirtan or katha video stream, and takes no room when only audio, or
/// nothing, is live. A tap opens that exact video in the YouTube app, or in
/// the browser on the web.
///
/// With no fresh answer, the timetable decides: the row shows in the usual
/// windows and a tap opens the channel's live page ([kYoutubeLiveUrl]).
///
/// It is a quiet row, like the Sangrand row: no card, a gold icon, 1 line. The
/// arrow at the end says the tap leaves this app.
class YoutubeLiveRow extends ConsumerWidget {
  const YoutubeLiveRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The link a tap opens, or null when the row is hidden.
    final link = ref.watch(youtubeLiveProvider);
    return AnimatedSize(
      duration: Motion.quick,
      curve: Motion.easeOut,
      alignment: Alignment.topCenter,
      child: link != null
          ? _Row(link: link)
          : const SizedBox(width: double.infinity),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.link});

  /// The video, or the channel's live page, that a tap opens.
  final String link;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Pressable(
        scale: 0.99,
        semanticLabel: l10n.youtube_live_semantics,
        onTap: () => openLink(link),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            // A target of 44 points or more, though the line is small.
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.play_rectangle,
                  size: 22,
                  color: Palette.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.youtube_live,
                    style: AppType.callout,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.arrow_up_right,
                  size: 13,
                  color: Palette.muted,
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
