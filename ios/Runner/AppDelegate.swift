import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
