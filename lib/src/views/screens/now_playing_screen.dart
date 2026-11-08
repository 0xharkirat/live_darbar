import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/stream_quality.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/widgets/artwork.dart';
import 'package:live_darbar/src/views/widgets/live_badge.dart';
import 'package:live_darbar/src/views/widgets/live_status_widget.dart';
import 'package:live_darbar/src/views/widgets/play_button.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/quality_sheet.dart';
import 'package:live_darbar/src/views/widgets/scrubber.dart';
import 'package:live_darbar/src/views/widgets/source_switcher.dart';
import 'package:live_darbar/src/views/widgets/spring_scale.dart';

/// Opens the full player as an iOS sheet.
///
/// The sheet pushes the home screen back and lets a downward drag, or a quick
/// flick, close it, tracking the finger 1:1 the whole way. That is the
/// gesture people already use to dismiss Apple Music's player.
///
/// A tap on the dimmed home above it closes it too. Flutter's Cupertino sheet
/// leaves that out, as an iOS sheet does, but a mouse cannot swipe, and a
/// finger often goes for the dim first.
///
/// [flickVelocity] is how fast a finger was moving up when it let go, in
/// points per second, as `DragEndDetails.primaryVelocity` reports it with the
/// sign dropped: up is positive. The sheet opens on a spring that starts at
/// that speed, so a flick throws it open and there is no seam between the
/// finger and the motion. A tap, with 0, opens it on the same spring from rest.
///
/// When the player is already open under the current page, as it is under a
/// reader opened by its Read button, this goes back to it instead of opening
/// a second one on top.
Future<void> showNowPlaying(BuildContext context, {double flickVelocity = 0}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final open = _PlayerSheetRoute._open;
  if (open != null && open.isActive && open.navigator == navigator) {
    navigator.popUntil((route) => route == open);
    return open.popped;
  }
  final height = MediaQuery.sizeOf(context).height;
  return navigator.push(
    _PlayerSheetRoute(
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      openVelocity: height > 0 ? math.max(0, flickVelocity) / height : 0,
      reduced: Motion.reduced(context),
    ),
  );
}

/// [showCupertinoSheet]'s route, with a barrier that dismisses.
///
/// It is named `/`, the page it sits on, because the address bar follows the
/// top route's name. Without a name, closing the reader that the player opened
/// would leave `#/hukamnama` showing over a player.
class _PlayerSheetRoute extends CupertinoSheetRoute<void> {
  _PlayerSheetRoute({
    required String barrierLabel,
    this.openVelocity = 0,
    this.reduced = false,
  })  : _barrierLabel = barrierLabel,
        super(
          settings: const RouteSettings(name: AppRoutes.home),
          showDragHandle: true,
          scrollableBuilder: (context, controller) =>
              NowPlayingScreen(scrollController: controller),
        );

  final String _barrierLabel;

  /// The player sheet in the navigator now, if there is one.
  static _PlayerSheetRoute? _open;

  @override
  void install() {
    super.install();
    _open = this;
  }

  @override
  void dispose() {
    if (identical(_open, this)) _open = null;
    super.dispose();
  }

  /// How fast the sheet was thrown open, in sheet heights per second.
  final double openVelocity;

  /// Reduce Motion is on. A simulation is not slowed to 5% the way a timed
  /// animation is, so under Reduce Motion the sheet keeps its own timing.
  final bool reduced;

  /// Opens on a spring that starts at [openVelocity]. The Cupertino sheet
  /// draws its controller through a curve, so the spring is played back
  /// through the inverse of that curve and the sheet on screen is the spring.
  /// Closing keeps the sheet's own motion: a drag hands its release speed to
  /// the route itself.
  @override
  Simulation? createSimulation({required bool forward}) {
    if (!forward || reduced) return null;
    final thrown = openVelocity >= Motion.flickSpeed;
    return SpringThroughCurve(
      SpringSimulation(
        thrown ? Motion.sheetFlick : Motion.sheet,
        0,
        1,
        openVelocity,
        snapToEnd: true,
      ),
      Curves.fastEaseInToSlowEaseOut,
    );
  }

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => _barrierLabel;
}

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key, this.scrollController});

  final ScrollController? scrollController;

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
    // Quality only applies to the broadcast, and the web has a single tier, so
    // its control shows only where it can change something.
    final hasQuality = now.isLive && !StreamQuality.isWeb;

    return Material(
      color: Palette.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(index: now.index),
          SafeArea(
            top: false,
            // Not at the bottom: the space for the navigation bar is inside
            // the scroll view, so the player slides under the bar and its last
            // line stops above it, as the update sheet does.
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                controller: scrollController,
                // The view padding, not the padding: the Cupertino sheet replaces
                // the padding its content sees, and with it the bottom, so a
                // `SafeArea` here never found the navigation bar.
                padding: EdgeInsets.fromLTRB(
                  24,
                  _topInset,
                  24,
                  16 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight -
                        _topInset -
                        32 -
                        MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Three groups. Parts of a group sit [_within] apart and
                          // the groups sit [_between] apart, so the eye reads three
                          // things and the rhythm is the same all the way down.
                          Column(
                            key: const Key('player_group_title'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _BreathingArtwork(
                                index: now.index,
                                playing: now.isPlaying,
                              ),
                              const SizedBox(height: _within),
                              Row(
                                key: const Key('player_title_row'),
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // The badge row is as tall as the Data saver
                                        // pill whether the pill shows or not, and
                                        // a recording holds the same space empty.
                                        // So neither the pill appearing nor a
                                        // change of source moves the artwork or the
                                        // title.
                                        SizedBox(
                                          height: DataSaverPill.height,
                                          child: now.isLive
                                              ? Row(
                                                  children: [
                                                    LiveBadge(
                                                      playing: now.isPlaying,
                                                    ),
                                                    if (hasQuality) ...[
                                                      const SizedBox(width: 10),
                                                      const DataSaverPill(),
                                                    ],
                                                  ],
                                                )
                                              : null,
                                        ),
                                        const SizedBox(height: 8),
                                        AnimatedSwitcher(
                                          duration: Motion.quick,
                                          child: Text(
                                            title,
                                            key: ValueKey(title),
                                            style: AppType.title,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(subtitle, style: AppType.callout),
                                      ],
                                    ),
                                  ),
                                  if (!now.isLive)
                                    _ReadButton(label: l10n.read),
                                ],
                              ),
                            ],
                          ),
                          // To the bar as the eye sees it, which starts inside
                          // the timeline's box.
                          const SizedBox(height: _between - Timeline.barInset),
                          Column(
                            key: const Key('player_group_controls'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Timeline(),
                              const SizedBox(height: _within),
                              _Transport(isLive: now.isLive, index: now.index),
                            ],
                          ),
                          const SizedBox(height: _between),
                          // The line about the stream sits with the switch that
                          // chooses the stream. It is empty most of the time, and
                          // then it takes no room.
                          Column(
                            key: const Key('player_group_source'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: LiveStatusLine(gap: _within / 2),
                              ),
                              const SourceSwitcher(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Top right, level with the sheet's drag handle, and on the content
          // column's right edge at every width. The column is 460 wide and
          // centred inside the 24 point margin, so this box is 460 + 2 * 24
          // wide and centred the same way, and the button sits 24 points in
          // from its right edge. On a phone the box is the screen.
          if (hasQuality)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460 + 2 * 24),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    heightFactor: 1,
                    child: Padding(
                      padding: EdgeInsets.only(right: 24),
                      child: QualityButton(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The gap between the parts of a group, and between the groups. Both are on
/// the app's 8 point grid, and the second is twice the first.
const _within = 16.0;
const _between = 32.0;

/// Space above the content for the quality button, which sits beside the
/// sheet's drag handle. The same for every source, and the badge row below the
/// artwork holds its height too, so switching between live and a recording
/// does not move the artwork.
const _topInset = 48.0;

/// The painting, blurred into a wash of its own colours, behind everything.
///
/// It is a static image under a static blur, so Flutter rasterises it once
/// and the sheet costs nothing per frame. The scrim keeps text above 7:1
/// whatever the painting's colours are.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: Motion.slow,
        child: Stack(
          key: ValueKey(index),
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Image.asset(
                artworkFor(index),
                fit: BoxFit.cover,
                cacheWidth: 200,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xA60C0A09), Color(0xF20C0A09)],
                  stops: [0, 0.6],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The artwork sits full size while sound plays and settles back when it
/// stops, so the state of the player is visible from across the room. It
/// moves on a spring that keeps its speed, so a pause that follows a play a
/// moment later turns smoothly instead of with a seam.
class _BreathingArtwork extends StatelessWidget {
  const _BreathingArtwork({required this.index, required this.playing});

  final int index;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return AspectRatio(
      // Close to the paintings' own 3:2, so all five ragis stay in frame.
      aspectRatio: 1.4,
      child: SpringScale(
        scale: playing || reduced ? 1 : 0.86,
        spring: Motion.artwork,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x59000000),
                blurRadius: 32,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: Motion.standard,
            // The switcher lays its children out loosely; without this the
            // painting keeps its own 3:2 shape inside the frame and the
            // shadow shows as a dark plate around it.
            child: SizedBox.expand(
              key: ValueKey(index),
              child: Artwork(index: index, radius: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class _Transport extends ConsumerWidget {
  const _Transport({required this.isLive, required this.index});

  final bool isLive;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // Skips stay in place on live, dimmed and inert, so the layout never
    // jumps when the source changes and the constraint is learnt, not hidden.
    Widget skip(IconData icon, String label, Duration by) => IgnorePointer(
          ignoring: isLive,
          child: AnimatedOpacity(
            opacity: isLive ? 0.25 : 1,
            duration: Motion.quick,
            child: Pressable(
              semanticLabel: label,
              scale: 0.9,
              onTap: () async {
                final p = ref.read(audioProgressProvider).value;
                if (p == null) return;
                final target = p.position + by;
                await ref.read(audioController).seek(
                      target < Duration.zero ? Duration.zero : target,
                    );
              },
              child: SizedBox.square(
                dimension: 56,
                child: Icon(icon, size: 30, color: Palette.foreground),
              ),
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        skip(
          CupertinoIcons.gobackward_15,
          l10n.skip_back,
          const Duration(seconds: -15),
        ),
        PlayButton(index: index, size: 76),
        skip(
          CupertinoIcons.goforward_15,
          l10n.skip_forward,
          const Duration(seconds: 15),
        ),
      ],
    );
  }
}

class _ReadButton extends StatelessWidget {
  const _ReadButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: () => Navigator.of(context, rootNavigator: true)
          .pushNamed(AppRoutes.hukamnama),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: ShapeDecoration(
          color: Palette.surfaceHigh,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Palette.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.book, size: 16, color: Palette.gold),
            const SizedBox(width: 6),
            Text(label,
                style: AppType.footnote.copyWith(color: Palette.foreground)),
          ],
        ),
      ),
    );
  }
}
