import AppIntents
import Foundation
import WidgetKit

// The iPhone widget's play buttons, on iOS 17 and newer.
//
// This file is a member of two targets: Runner, and the widget extension.
// An `AudioPlaybackIntent` runs in the app's process, not the widget's, and
// the system only does that for an intent that the app itself contains.
// With the type in the extension alone, the intent runs in the extension,
// which may not play audio. Runner builds this file with
// `-DLIVE_DARBAR_APP`. The extension's copy has no Flutter, so it compiles
// without that flag, and its `perform` does nothing: the system never calls
// it. The widget needs the type to draw `Button(intent:)`.
//
// iOS 16 keeps the `Link` buttons that open the app. See
// LiveDarbarWidgetView.swift.

/// A source that a widget button plays or stops. The names are the ones in
/// lib/src/home_screen_widget/widget_playback.dart (`WidgetSource`).
enum WidgetPlaySource: String {
  case live
  case hukamnama
}

/// The widget's store, as far as a tap needs it: write "loading", and redraw.
enum WidgetTapStore {
  /// kIosAppGroupId in widget_data.dart, and both targets' entitlements.
  static let appGroup = "group.com.hsiharki.liveDarbar"

  /// kIosWidgetKind in widget_data.dart.
  static let widgetKind = "LiveDarbarWidget"

  /// The key of WidgetKeys.playback in widget_data.dart.
  static let playbackKey = "ld_playback"

  /// Makes the button answer at once, before the app plays. Android does the
  /// same (WidgetControlReceiver.kt): the receiver writes "loading" for the
  /// source and redraws, and the app writes the real state once it has one.
  ///
  /// A tap on a button that already shows the source on is a stop or a
  /// pause, so nothing is written for it. The app decides from the real
  /// player either way. This only keeps the picture honest while it waits.
  static func showLoadingIfStarting(_ source: WidgetPlaySource) {
    guard let store = UserDefaults(suiteName: appGroup) else { return }
    if let text = store.string(forKey: playbackKey),
      let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
      json["source"] as? String == source.rawValue,
      let state = json["state"] as? String,
      state == "playing" || state == "loading"
    {
      return
    }
    let at = Int(Date().timeIntervalSince1970 * 1000)
    store.set(
      "{\"state\":\"loading\",\"source\":\"\(source.rawValue)\",\"at\":\(at),\"by\":\"widget\"}",
      forKey: playbackKey
    )
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
  }

  /// The app never answered, so the "loading" would only lapse by itself
  /// after a minute. Draw the buttons as idle now.
  static func showIdle() {
    guard let store = UserDefaults(suiteName: appGroup) else { return }
    let at = Int(Date().timeIntervalSince1970 * 1000)
    store.set(
      "{\"state\":\"idle\",\"source\":null,\"at\":\(at),\"by\":\"widget\"}",
      forKey: playbackKey
    )
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
  }
}

/// The Live Kirtan button: plays the live stream, or stops it.
@available(iOS 17.0, *)
struct LiveKirtanWidgetIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Play or stop Live Kirtan"
  static var openAppWhenRun: Bool = false
  /// Only the widget uses it. Keep it out of Shortcuts.
  static var isDiscoverable: Bool = false

  func perform() async throws -> some IntentResult {
    #if LIVE_DARBAR_APP
      WidgetTapStore.showLoadingIfStarting(.live)
      await WidgetPlayHost.send(.live)
    #endif
    return .result()
  }
}

/// The Hukamnama button: plays today's Hukamnama, or pauses it.
@available(iOS 17.0, *)
struct HukamnamaWidgetIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Play or pause the Hukamnama"
  static var openAppWhenRun: Bool = false
  static var isDiscoverable: Bool = false

  func perform() async throws -> some IntentResult {
    #if LIVE_DARBAR_APP
      WidgetTapStore.showLoadingIfStarting(.hukamnama)
      await WidgetPlayHost.send(.hukamnama)
    #endif
    return .result()
  }
}
