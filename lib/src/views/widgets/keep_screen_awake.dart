import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/services/screen_awake.dart';

/// Keeps the screen on while [child] is on screen and the app is in front.
///
/// It lets go when the page closes, and when the app goes behind another one
/// or to the home screen, and holds again when the app comes back. A page that
/// is read slowly with no touch uses it, and no other page should.
class KeepScreenAwake extends ConsumerStatefulWidget {
  const KeepScreenAwake({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KeepScreenAwake> createState() => _KeepScreenAwakeState();
}

class _KeepScreenAwakeState extends ConsumerState<KeepScreenAwake> {
  late final ScreenAwake _awake = ref.read(screenAwakeProvider);
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: _onState,
  );
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _lifecycle;
    // A page that opens while the app is behind another (a tap on the
    // reminder that starts the app) holds the screen when it comes to the
    // front, not before.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _hold();
  }

  void _onState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hold();
    } else {
      _release();
    }
  }

  void _hold() {
    if (_holding) return;
    _holding = true;
    _awake.hold();
  }

  void _release() {
    if (!_holding) return;
    _holding = false;
    _awake.release();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
