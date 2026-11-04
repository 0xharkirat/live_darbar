import Flutter
import UIKit

/// Sends a widget button's tap to Dart, in the app's process, with no screen.
///
/// Only Runner builds this file (WidgetPlayIntents.swift reaches it under
/// `LIVE_DARBAR_APP`). The widget extension has no Flutter.
///
/// The engine is the one AppDelegate owns. A cold start from the widget runs
/// `didFinishLaunching` with no scene, so the engine and `main()` start there,
/// and the intent only has to wait for Dart to listen. When the listener opens
/// the app later, the scene shows this same engine, so the screen and the
/// background tap share one audio handler.
enum WidgetPlayHost {
  /// lib/src/home_screen_widget/widget_remote.dart listens on the same name.
  static let channelName = "com.hsi.harki.live_darbar/widget_control"

  /// A cold start needs the engine, the plugins and the media session before
  /// Dart listens. A few seconds on a slow phone, so give it a long wait.
  /// The system lets a background intent run for a short time, not for ever.
  static let giveUpAfter: TimeInterval = 20

  /// Returns once Dart has done the tap, or the wait has run out.
  @MainActor
  static func send(_ source: WidgetPlaySource) async {
    guard let engine = (UIApplication.shared.delegate as? AppDelegate)?.sharedEngine else {
      WidgetTapStore.showIdle()
      return
    }
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engine.binaryMessenger
    )
    let deadline = Date().addingTimeInterval(giveUpAfter)
    repeat {
      let answer = await ask(channel, source.rawValue)
      // Dart that is not listening yet answers with "not implemented".
      let notReady = (answer as? NSObject) === FlutterMethodNotImplemented
      if !notReady {
        if answer is FlutterError { WidgetTapStore.showIdle() }
        return
      }
      try? await Task.sleep(nanoseconds: 250_000_000)
    } while Date() < deadline
    WidgetTapStore.showIdle()
  }

  private static func ask(_ channel: FlutterMethodChannel, _ argument: String) async -> Any? {
    await withCheckedContinuation { continuation in
      channel.invokeMethod("tap", arguments: argument) { continuation.resume(returning: $0) }
    }
  }
}
