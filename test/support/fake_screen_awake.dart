/// Stands in for the phone's screen timeout, and records what the app asks.
///
/// Give [toggle] to `ScreenAwake`. [on] is whether the screen is held awake
/// now, and [calls] is each request in order.
class FakeScreenAwake {
  bool on = false;
  final calls = <bool>[];

  Future<void> toggle(bool enable) async {
    on = enable;
    calls.add(enable);
  }
}
