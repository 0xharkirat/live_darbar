import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:video_player/video_player.dart';

/// A tap on a film: where, when, and for how long the finger stays down.
///
/// [x] and [y] are fractions of the screen in the film. A press that [hold]s
/// keeps the finger down for that many seconds, and a drag also names where it
/// ends, in [toX] and [toY].
///
/// The times were measured on the film itself, not on the clock of the phone
/// that made it. The iPhone film's come from the tap log of
/// `tool/ios_widget_driver` (`testFilm`); the Android film's were read from its
/// frames, because `adb` times a tap to about 0.3 s.
@immutable
class TapMark {
  const TapMark(
    this.t,
    this.x,
    this.y, {
    this.hold = 0,
    this.toX,
    this.toY,
  });

  final double t;
  final double x;
  final double y;
  final double hold;
  final double? toX;
  final double? toY;

  double get endX => toX ?? x;
  double get endY => toY ?? y;
  double get endT => t + hold;
}

/// A film that shows the steps, with the places to draw its taps.
@immutable
class DemoFilm {
  const DemoFilm({
    required this.video,
    required this.poster,
    required this.pixels,
    required this.seconds,
    required this.marks,
    required this.outerRadius,
    required this.screenRadius,
    required this.stepStarts,
    required this.stepsEnd,
  });

  /// The asset of the film: H.264, no sound, looped.
  final String video;

  /// The first picture of the film. It shows until the film plays, if it
  /// cannot play, and under Reduce Motion.
  final String poster;

  /// The film's own size in pixels. Its ratio is the ratio of the screen.
  final Size pixels;

  final double seconds;
  final List<TapMark> marks;

  /// The corners of the phone and of its screen, as fractions of the phone's
  /// width. The iPhone's follow the demo film on darbar.live (`site/styles.css`,
  /// `.device` and `.screen`).
  final double outerRadius;
  final double screenRadius;

  double get aspect => pixels.width / pixels.height;

  /// When each of the sheet's 3 steps starts in the film, in seconds: a little
  /// before the step's first tap, so its number lights as the dot sets off.
  final List<double> stepStarts;

  /// When the last step ends. After it the film shows the widget at work, which
  /// is no step, so no number is lit.
  final double stepsEnd;

  /// The step (0, 1 or 2) the film shows at [seconds], or null when it shows
  /// none.
  int? stepAt(double seconds) {
    if (seconds < 0 || seconds >= stepsEnd) return null;
    for (var i = stepStarts.length - 1; i >= 0; i--) {
      if (seconds >= stepStarts[i]) return i;
    }
    return null;
  }

  /// An iPhone adding the widget: 19.3 s, 540 x 1174.
  ///
  /// It was recorded on an iPhone 17 Pro simulator by the XCUITest driver in
  /// `tool/ios_widget_driver`, with every wait of over 0.6 s cut out.
  static const iphone = DemoFilm(
    video: 'assets/videos/add_widget_iphone.mp4',
    poster: 'assets/videos/add_widget_iphone_poster.webp',
    pixels: Size(540, 1174),
    seconds: 19.3,
    outerRadius: 0.16,
    screenRadius: 0.135,
    // Press and hold; Edit and Add Widget; the search and the medium size.
    // After that, Done and Live Kirtan from the widget.
    stepStarts: [0, 2.2, 5.5],
    stepsEnd: 13.4,
    marks: [
      // Press and hold an empty spot, Edit, Add Widget.
      TapMark(0.457, 0.5, 0.55, hold: 1.0),
      TapMark(2.534, 0.1791, 0.0378),
      TapMark(4.455, 0.3997, 0.1064),
      // The search field, the app's row, and Add Widget.
      TapMark(5.87, 0.5, 0.2014),
      TapMark(8.686, 0.35, 0.29),
      TapMark(11.067, 0.5, 0.905),
      // Done, then Live Kirtan from the widget.
      TapMark(13.839, 0.8209, 0.0378),
      TapMark(16.002, 0.7005, 0.2475),
    ],
  );

  /// An Android launcher adding the widget by hand: 16.5 s, 540 x 1116.
  static const android = DemoFilm(
    video: 'assets/videos/add_widget_manual_android.mp4',
    poster: 'assets/videos/add_widget_manual_android_poster.webp',
    pixels: Size(540, 1116),
    seconds: 16.5,
    outerRadius: 0.115,
    screenRadius: 0.085,
    // Press and hold; Widgets; Browse, the list, and the drag.
    stepStarts: [0, 1.9, 4.3],
    stepsEnd: 14.2,
    marks: [
      // Press and hold the home screen, Widgets, Browse.
      TapMark(0.25, 0.5, 0.405, hold: 0.9),
      TapMark(2.25, 0.63, 0.207),
      TapMark(4.7, 0.646, 0.956),
      // 2 swipes up the list, to Live Darbar, and a tap on it.
      TapMark(6.55, 0.5, 0.808, hold: 0.4, toX: 0.5, toY: 0.27),
      TapMark(7.6, 0.5, 0.787, hold: 0.7, toX: 0.5, toY: 0.405),
      TapMark(9.95, 0.37, 0.385),
      // The widget's picture, dragged on to the home screen.
      TapMark(12.0, 0.5, 0.57, hold: 1.8, toX: 0.5, toY: 0.315),
    ],
  );
}

// ---- The player, behind a small interface so a test can stand in for it ----

/// What a [FilmPlayer] reports.
@immutable
class FilmValue {
  const FilmValue({
    this.playing = false,
    this.hasError = false,
    this.position = Duration.zero,
  });

  final bool playing;
  final bool hasError;
  final Duration position;

  /// A film that plays has put its first picture on screen.
  bool get onScreen => playing && !hasError && position > Duration.zero;
}

/// Plays 1 film, muted and looped. [VideoFilmPlayer] is the real one.
abstract interface class FilmPlayer implements ValueListenable<FilmValue> {
  /// Throws when the film cannot play.
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();

  /// The picture, drawn to fill the box it is given.
  Widget view();

  Future<void> dispose();
}

typedef FilmPlayerFactory = FilmPlayer Function(String asset);

/// How the app makes a [FilmPlayer]. A test overrides it.
final filmPlayerFactoryProvider = Provider<FilmPlayerFactory>(
  (ref) => VideoFilmPlayer.new,
);

/// The official `video_player`, muted and looping, with no controls.
///
/// The films have no sound track, and the player must not take the sound from
/// the kirtan either. On Android, ExoPlayer asks for audio focus the moment it
/// plays, with or without a sound track, and the kirtan would pause: so the
/// player mixes with others there. On iPhone, AVPlayer leaves the audio session
/// alone for a film with no sound. Any value for `mixWithOthers`, even false,
/// makes the plugin set the category of the whole app's audio session, so
/// iPhone gives no options at all.
class VideoFilmPlayer extends ChangeNotifier implements FilmPlayer {
  VideoFilmPlayer(String asset)
      : _controller = VideoPlayerController.asset(
          asset,
          videoPlayerOptions: defaultTargetPlatform == TargetPlatform.android
              ? VideoPlayerOptions(mixWithOthers: true)
              : null,
        ) {
    _controller.addListener(_changed);
  }

  final VideoPlayerController _controller;
  var _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  FilmValue get value {
    final v = _controller.value;
    return FilmValue(
      playing: v.isPlaying,
      hasError: v.hasError,
      position: v.position,
    );
  }

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    await _controller.setLooping(true);
    await _controller.setVolume(0);
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Widget view() => VideoPlayer(_controller);

  @override
  Future<void> dispose() async {
    _disposed = true;
    _controller.removeListener(_changed);
    await _controller.dispose();
    super.dispose();
  }
}

// ---- The film in its phone ----

/// A film in a phone frame, with the taps drawn over it.
///
/// The film plays by itself, muted, in a loop, with no controls. The poster
/// shows until the first picture is on screen, and stays if the film cannot
/// play. The film pauses when the app goes to the background, when the sheet
/// that holds it closes or is covered, and it does not play at all under Reduce
/// Motion, which shows the poster only.
///
/// The frame follows the demo film on darbar.live: a bezel of 3% of the width,
/// and a hairline ring where light catches the edge. It has no drop shadow:
/// the sheet is as dark as the shadow would be.
///
/// It shows the 3 steps of the sheet it sits in, so it hides from a screen
/// reader, and the words say the same.
class DemoFilmView extends ConsumerStatefulWidget {
  const DemoFilmView({
    super.key,
    required this.film,
    required this.width,
    this.onStep,
  });

  final DemoFilm film;

  /// The width of the whole frame, bezel included.
  final double width;

  /// Called when the film moves to another step ([DemoFilm.stepAt]), so the
  /// sheet can light that step's number. Null while the film shows no step,
  /// and while only the poster shows.
  final ValueChanged<int?>? onStep;

  @override
  ConsumerState<DemoFilmView> createState() => _DemoFilmViewState();
}

class _DemoFilmViewState extends ConsumerState<DemoFilmView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  FilmPlayer? _player;
  var _failed = false;
  var _foreground = true;
  var _closed = false;

  /// The film's time in seconds, for the taps. It runs on the screen's own
  /// clock between the player's reports, and takes the player's word at each.
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_tick);
  double _anchorSeconds = 0;
  Duration _anchorAt = Duration.zero;
  Duration _lastTick = Duration.zero;

  /// The step last reported to [DemoFilmView.onStep].
  int? _step;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _time.addListener(_stepChanged);
  }

  void _stepChanged() {
    final playing = _player?.value.onScreen ?? false;
    final step = playing ? widget.film.stepAt(_time.value) : null;
    if (step == _step) return;
    _step = step;
    widget.onStep?.call(step);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  /// Opens the player, plays it, or pauses it, to match what the screen allows.
  void _sync() {
    if (_closed) return;
    if (Motion.reduced(context)) {
      _release();
      return;
    }
    final player = _player;
    if (player == null) {
      if (!_failed) unawaited(_open());
      return;
    }
    if (_foreground && TickerMode.valuesOf(context).enabled) {
      unawaited(_guard(player.play));
    } else {
      unawaited(_guard(player.pause));
    }
  }

  Future<void> _open() async {
    final player = ref.read(filmPlayerFactoryProvider)(widget.film.video);
    _player = player;
    player.addListener(_reported);
    try {
      await player.initialize();
    } catch (error, stack) {
      debugPrint('The demo film did not open: $error\n$stack');
      _fail(player);
      return;
    }
    if (_closed || _player != player) return;
    _sync();
    if (mounted) setState(() {});
  }

  /// A film that cannot play leaves the poster, and does not try again.
  void _fail(FilmPlayer player) {
    if (_player == player) {
      _player = null;
      _failed = true;
      if (mounted) setState(() {});
    }
    _ticker.stop();
    _stepChanged();
    unawaited(_dispose(player));
  }

  /// Gives the player up, because Reduce Motion came on. The build that
  /// follows shows the poster.
  void _release() {
    final player = _player;
    if (player == null) return;
    _player = null;
    _ticker.stop();
    _stepChanged();
    unawaited(_dispose(player));
  }

  Future<void> _dispose(FilmPlayer player) async {
    player.removeListener(_reported);
    await _guard(player.pause);
    await _guard(player.dispose);
  }

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      debugPrint('The demo film player: $error');
    }
  }

  void _reported() {
    final player = _player;
    if (player == null) return;
    final v = player.value;
    if (v.hasError) {
      _fail(player);
      return;
    }
    if (v.playing) {
      _anchorSeconds = v.position.inMicroseconds / 1e6;
      _anchorAt = _lastTick;
      if (!_ticker.isActive) {
        _anchorAt = Duration.zero;
        _lastTick = Duration.zero;
        unawaited(_ticker.start());
      }
    } else {
      _ticker.stop();
    }
    _stepChanged();
    if (mounted) setState(() {});
  }

  void _tick(Duration elapsed) {
    _lastTick = elapsed;
    final t = _anchorSeconds + (elapsed - _anchorAt).inMicroseconds / 1e6;
    _time.value = t.clamp(0, widget.film.seconds).toDouble();
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    final player = _player;
    _player = null;
    _ticker.dispose();
    _time.dispose();
    if (player != null) unawaited(_dispose(player));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final film = widget.film;
    final width = widget.width;
    final bezel = width * 0.03;
    final screenWidth = width - 2 * bezel;
    final screenHeight = screenWidth / film.aspect;
    final player = _player;
    final reduced = Motion.reduced(context);
    final shown = !reduced && player != null && player.value.onScreen;

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: screenHeight + 2 * bezel,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(width * film.outerRadius),
              // The film's hairline ring: light catching the edge.
              side: BorderSide(
                color: Palette.foreground.withValues(alpha: 0.14),
              ),
            ),
            gradient: const LinearGradient(
              begin: Alignment(-0.5, -1),
              end: Alignment(0.5, 1),
              colors: [Color(0xFF2A2420), Color(0xFF0F0D0C), Color(0xFF1A1612)],
              stops: [0, 0.55, 1],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(bezel),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(width * film.screenRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    film.poster,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                  if (player != null)
                    // The film fades in over the poster, which is its first
                    // picture, so the fade shows nothing but the film starting.
                    // Entering UI eases out.
                    AnimatedOpacity(
                      opacity: shown ? 1 : 0,
                      duration: Motion.standard,
                      curve: Motion.easeOut,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: film.pixels.width,
                          height: film.pixels.height,
                          child: player.view(),
                        ),
                      ),
                    ),
                  if (shown)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: TapMarksPainter(film: film, time: _time),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- The taps ----

/// Where the touch is, and how it looks, at 1 moment of a film.
///
/// The same drawing as the cursor on darbar.live (`site/demo.js`): a light dot
/// glides from tap to tap, sinks a little where it presses, and sends out a
/// ring. It is a function of the film's time only, so a loop, a pause and a
/// jump all show the same taps.
@immutable
class TouchState {
  const TouchState({
    required this.x,
    required this.y,
    required this.press,
    required this.ring,
    required this.opacity,
  });

  /// Fractions of the screen.
  final double x;
  final double y;

  /// 1 at rest, down to 0.86 at a press.
  final double press;

  /// 0 as the ring starts, 1 as it is gone, or -1 for none.
  final double ring;

  final double opacity;
}

abstract final class TapMarks {
  /// The dot takes this long to travel to a tap, the same as the site's cursor.
  static const travel = 0.95;
  static const _pressTime = 0.22;
  static const _ringTime = 0.5;

  /// A cubic ease in and out, as on the site.
  static double _ease(double p) =>
      p < 0.5 ? 4 * p * p * p : 1 - math.pow(-2 * p + 2, 3) / 2;

  /// The dot's path: [t, x, y] keys. It starts a little off the first tap,
  /// waits where it is, and leaves [travel] seconds before the next one.
  static List<List<double>> path(DemoFilm film) {
    final marks = film.marks;
    final first = marks.first;
    final keys = <List<double>>[
      [0, first.x + 0.10, first.y + 0.09],
    ];
    var prevT = 0.0;
    var prevX = keys.first[1];
    var prevY = keys.first[2];
    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      final depart = i == 0 ? 0.0 : math.max(m.t - travel, prevT + 0.15);
      if (depart > prevT + 0.01) keys.add([depart, prevX, prevY]);
      keys.add([m.t, m.x, m.y]);
      if (m.hold > 0) keys.add([m.endT, m.endX, m.endY]);
      prevT = m.endT;
      prevX = m.endX;
      prevY = m.endY;
    }
    keys.add([film.seconds, prevX, prevY]);
    return keys;
  }

  static TouchState at(DemoFilm film, double t, [List<List<double>>? keys]) {
    final k = keys ?? path(film);
    double x;
    double y;
    if (t <= k.first[0]) {
      x = k.first[1];
      y = k.first[2];
    } else if (t >= k.last[0]) {
      x = k.last[1];
      y = k.last[2];
    } else {
      var i = 0;
      while (i < k.length - 2 && t >= k[i + 1][0]) {
        i++;
      }
      final span = k[i + 1][0] - k[i][0];
      final e = span <= 0 ? 1.0 : _ease((t - k[i][0]) / span);
      x = k[i][1] + (k[i + 1][1] - k[i][1]) * e;
      y = k[i][2] + (k[i + 1][2] - k[i][2]) * e;
    }

    // The press: the finger sinks, stays down for a hold, and comes back up.
    var press = 1.0;
    var ring = -1.0;
    for (final m in film.marks) {
      final d = t - m.t;
      if (d < 0) continue;
      if (d < m.hold) {
        press = math.min(press, 0.86 + 0.14 * (1 - _smooth(d / _pressTime)));
      } else {
        final up = d - m.hold;
        if (up < _pressTime) {
          press =
              math.min(press, 1 - 0.14 * math.sin(up / _pressTime * math.pi));
        }
      }
      if (d < _ringTime) ring = d / _ringTime;
    }

    // It appears as the film starts and goes before the loop comes round.
    final opacity = math.min(
      ((t - 0.05) / 0.25).clamp(0.0, 1.0),
      ((film.seconds - t) / 0.4).clamp(0.0, 1.0),
    );
    return TouchState(x: x, y: y, press: press, ring: ring, opacity: opacity);
  }

  static double _smooth(double p) {
    final c = p.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }
}

/// Draws the touch of a film on the screen it plays on.
class TapMarksPainter extends CustomPainter {
  TapMarksPainter({required this.film, required this.time})
      : _path = TapMarks.path(film),
        super(repaint: time);

  final DemoFilm film;
  final ValueListenable<double> time;
  final List<List<double>> _path;

  @override
  void paint(Canvas canvas, Size size) {
    final s = TapMarks.at(film, time.value, _path);
    if (s.opacity <= 0) return;
    final w = size.width;
    final centre = Offset(s.x * size.width, s.y * size.height);

    // The ring, which leaves the touch.
    if (s.ring >= 0) {
      final out = 1 - math.pow(1 - s.ring, 3);
      final radius = w * 0.1375 / 2 * (0.35 + 0.95 * out);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.25, w * 0.00625)
          ..color = const Color(0xFFF5F1EB)
              .withValues(alpha: 0.8 * (1 - s.ring) * s.opacity),
      );
    }

    // The dot: light, with a dark edge, so it shows on the gold and the dark.
    final radius = w * 0.125 / 2 * (s.press * 0.96 + 0.04);
    canvas.drawCircle(
      centre.translate(0, w * 0.006),
      radius,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.28 * s.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.015),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.5 * s.opacity),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.0047)
        ..color = const Color(0xFF000000).withValues(alpha: 0.4 * s.opacity),
    );
  }

  @override
  bool shouldRepaint(TapMarksPainter old) =>
      old.film != film || old.time != time;
}
