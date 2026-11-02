import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:live_darbar/src/core/open_link.dart';

/// How long a button stays busy after a tap, if nothing ends it sooner.
const _busyFor = Duration(milliseconds: 1500);

/// Builds a button that opens [url] in the in-app browser, and keeps it busy
/// until the browser covers the app.
///
/// A Chrome Custom Tab that starts cold can take 0.5 to 1.5 seconds to cover
/// the app. A [Pressable] lets go on touch-up, in the same frame as the tap,
/// so in that gap the button looked idle and a second tap opened a second
/// tab. Here the button is busy from the tap until the app is paused or hidden
/// by the browser, or [_busyFor] has passed, whichever comes first. While it
/// is busy, [builder] gets a null `open`, which is how a button says it is off.
class InAppLink extends StatefulWidget {
  const InAppLink({super.key, required this.url, required this.builder});

  final String url;

  /// Builds the button. `opening` is true while the browser is on its way, and
  /// `open` is the tap handler, or null while `opening`.
  final Widget Function(BuildContext context, bool opening, VoidCallback? open)
      builder;

  @override
  State<InAppLink> createState() => _InAppLinkState();
}

class _InAppLinkState extends State<InAppLink> with WidgetsBindingObserver {
  bool _opening = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _done();
    }
  }

  void _open() {
    setState(() => _opening = true);
    _timer = Timer(_busyFor, _done);
    // Never throws: openLinkInApp swallows its own failures.
    unawaited(openLinkInApp(widget.url));
  }

  void _done() {
    _timer?.cancel();
    if (_opening && mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _opening, _opening ? null : _open);
  }
}
