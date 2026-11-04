import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';

/// The timeline: a scrubber for recordings, a live rail for the broadcast.
///
/// Both occupy the same height, so switching source never moves the transport
/// buttons below.
class Timeline extends ConsumerWidget {
  const Timeline({super.key});

  /// The height at the default text size. The timeline grows from here with
  /// the listener's text size, so the times under the bar are never cut.
  static const _height = 44.0;

  /// What sits above the times: the gaps and the bar, in either state.
  static const _aboveTimes = 24.0;

  /// The space above the bar inside the timeline's box. It is room for the
  /// bar to thicken under a finger and for the finger itself. The live rail
  /// keeps the same space, so the bar is at the same place in both. A layout
  /// that wants a gap above the bar as the eye sees it takes this off.
  static const barInset = 10.0;

  static double _heightOf(BuildContext context) {
    final style = AppType.timecode;
    final line = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize! * style.height!);
    return math.max(_height, _aboveTimes + line);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioProgressProvider).value;
    final isLive = progress?.isLive ?? true;

    return SizedBox(
      height: _heightOf(context),
      child: AnimatedSwitcher(
        duration: Motion.quick,
        child: isLive || progress == null
            ? const _LiveRail(key: ValueKey('live'))
            : _Scrubber(
                key: const ValueKey('scrubber'),
                progress: progress,
                onSeek: (d) => ref.read(audioController).seek(d),
              ),
      ),
    );
  }
}

/// A broadcast has no length and nothing to seek, so it gets a full rail with
/// "LIVE" at the end instead of a scrubber that would promise both.
class _LiveRail extends StatelessWidget {
  const _LiveRail({super.key});

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.live.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Timeline.barInset),
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Palette.gold.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.live,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppType.timecode.copyWith(
                letterSpacing: AppType.tracking ? 0.8 : 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Scrubber extends StatefulWidget {
  const _Scrubber({super.key, required this.progress, required this.onSeek});

  final AudioProgressState progress;
  final Future<void> Function(Duration) onSeek;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  /// Where the finger is, 0 to 1, while dragging. Null when not dragging, so
  /// the bar follows the player again the moment the finger lifts.
  double? _drag;

  Duration get _total => widget.progress.totalDuration ?? Duration.zero;

  double _fraction(Duration d) {
    final total = _total.inMilliseconds;
    if (total <= 0) return 0;
    return (d.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _update(Offset local, double width) {
    setState(() => _drag = (local.dx / width).clamp(0.0, 1.0));
  }

  Future<void> _commit() async {
    final f = _drag;
    if (f == null) return;
    await widget.onSeek(_total * f);
    if (mounted) setState(() => _drag = null);
  }

  @override
  Widget build(BuildContext context) {
    final hasDuration = widget.progress.hasDuration;
    final played = _drag ?? _fraction(widget.progress.position);
    final buffered = _fraction(widget.progress.bufferedPosition);
    final dragging = _drag != null;
    final elapsed = hasDuration ? _total * played : Duration.zero;
    final remaining = _total - elapsed;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart:
              hasDuration ? (d) => _update(d.localPosition, width) : null,
          onHorizontalDragUpdate:
              hasDuration ? (d) => _update(d.localPosition, width) : null,
          onHorizontalDragEnd: hasDuration ? (_) => _commit() : null,
          onTapUp: hasDuration
              ? (d) {
                  _update(d.localPosition, width);
                  _commit();
                }
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 8,
                child: Center(
                  // The bar thickens under the finger: the target grows while
                  // it is being used, Apple Music's trick.
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    curve: Motion.easeOut,
                    height: dragging ? 8 : 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CustomPaint(
                        size: Size(width, dragging ? 8 : 4),
                        painter: _BarPainter(
                          played: hasDuration ? played : 0,
                          buffered: hasDuration ? buffered : 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(_format(elapsed), style: AppType.timecode),
                  const Spacer(),
                  Text(
                    hasDuration ? '−${_format(remaining)}' : '--:--',
                    style: AppType.timecode,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.played, required this.buffered});

  final double played;
  final double buffered;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    void bar(double f, Color c) {
      if (f <= 0) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * f, size.height),
          Radius.circular(r),
        ),
        Paint()..color = c,
      );
    }

    bar(1, Palette.border);
    bar(buffered, Palette.faint);
    bar(played, Palette.gold);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.played != played || old.buffered != buffered;
}
