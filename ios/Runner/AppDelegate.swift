import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// The app's one Flutter engine. It starts here, in `didFinishLaunching`, and
  /// not when a screen appears, so the iPhone widget's play buttons can start
  /// it with no scene: the system launches the app in the background for an
  /// `AudioPlaybackIntent`, and that launch has no window. SceneDelegate shows
  /// this same engine when the listener opens the app, so the screen and the
  /// widget share one audio handler. See WidgetPlayHost.swift.
  private(set) var sharedEngine: FlutterEngine?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let engine = FlutterEngine(name: "live_darbar", project: nil, allowHeadlessExecution: true)
    sharedEngine = engine
    // A plugin cannot set its message handler before the engine has run.
    // Dart's first plugin call waits for the platform thread, which is busy
    // here, so the plugins are in place by then.
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // When the listener closes the app while it plays, the sound stops, but
  // the widget still holds the last state the app wrote, "playing". Write
  // "idle" now, so the widget does not show a stop button for kirtan that is
  // not there. The shape is the one encodeWidgetPlayback writes in
  // lib/src/home_screen_widget/widget_playback.dart.
  override func applicationWillTerminate(_ application: UIApplication) {
    if let store = UserDefaults(suiteName: "group.com.hsiharki.liveDarbar") {
      let at = Int(Date().timeIntervalSince1970 * 1000)
      store.set(
        "{\"state\":\"idle\",\"source\":null,\"at\":\(at),\"by\":\"app\"}",
        forKey: "ld_playback"
      )
      WidgetCenter.shared.reloadTimelines(ofKind: "LiveDarbarWidget")
    }
    super.applicationWillTerminate(application)
  }
}
