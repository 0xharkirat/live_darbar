import 'package:live_darbar/src/core/widget_card_rules.dart';
import 'package:live_darbar/src/home_screen_widget/widget_install.dart';

/// Stands in for the phone behind the "add the widget" card, and records what
/// the app asks of it.
class FakeWidgetInstall implements WidgetInstall {
  FakeWidgetInstall({
    this.supported = true,
    this.iphone = false,
    this.pinSupported = true,
    this.placementNow = WidgetPlacement.absent,
  });

  bool supported;
  bool iphone;

  /// Whether the launcher can pin a widget. An iPhone never can.
  bool pinSupported;

  /// What the phone answers when asked where the widget is. Set it between
  /// checks, as a listener adding the widget would.
  WidgetPlacement placementNow;

  /// Set to make [placement] fail, as a phone can.
  Object? placementError;

  /// Each call, in order: `placement` and `pin`.
  final calls = <String>[];

  int get pinCount => calls.where((c) => c == 'pin').length;
  int get placementCount => calls.where((c) => c == 'placement').length;

  @override
  bool get isSupported => supported;

  @override
  bool get isIphone => iphone;

  @override
  Future<WidgetPlacement> placement() async {
    calls.add('placement');
    final error = placementError;
    if (error != null) throw error;
    return placementNow;
  }

  @override
  Future<bool> requestPin() async {
    if (!pinSupported || iphone) return false;
    calls.add('pin');
    return true;
  }
}
