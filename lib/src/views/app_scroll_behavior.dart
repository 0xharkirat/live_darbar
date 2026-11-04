import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// How the app's scroll views behave, in `MaterialApp.scrollBehavior`.
///
/// On the web every vertical scroll view gets a scrollbar. Flutter's own
/// behavior draws one only when the browser reports a desktop system, so a
/// narrow window on a laptop does, and a phone's browser does not, and a
/// listener on a long page like the Hukamnama reader has no sign of where they
/// are or how much is left. A scrollbar fades out when nobody scrolls, so it
/// costs a touch screen nothing.
///
/// Everywhere else it is Flutter's behavior, so the phone apps are as they
/// were.
class AppScrollBehavior extends MaterialScrollBehavior {
  /// [web] is for tests. The app passes nothing.
  const AppScrollBehavior({bool? web}) : _web = web;

  final bool? _web;

  bool get _onWeb => _web ?? (kIsWeb || kIsWasm);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (_onWeb && axisDirectionToAxis(details.direction) == Axis.vertical) {
      return Scrollbar(controller: details.controller, child: child);
    }
    return super.buildScrollbar(context, child, details);
  }
}
