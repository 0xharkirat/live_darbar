import Foundation

/// Reads what the app wrote for the widget, and turns it into a picture.
///
/// The app writes the store through home_widget, in the App Group. The keys,
/// the JSON shapes and the states are the ones in
/// lib/src/home_screen_widget/widget_data.dart and widget_playback.dart.
/// test/home_screen_widget/native_contract_test.dart checks that this file
/// names the same keys.
struct WidgetStore {
  /// kIosAppGroupId in widget_data.dart, and both targets' entitlements.
  static let appGroup = "group.com.hsiharki.liveDarbar"

  enum Key {
    static let language = "ld_language"
    static let title = "ld_title"
    static let dates = "ld_dates"
    static let line = "ld_line"
    static let linePauses = "ld_line_pauses"
    static let lineMeaning = "ld_line_meaning"
    static let hukamnamaMeta = "ld_hukamnama_meta"
    static let openLabel = "ld_open_label"
    static let labels = "ld_labels"
    static let playback = "ld_playback"
  }

  /// The top line's separator. Dart joins the date and the Ang with it.
  static let separator = " · "

  /// A "loading" state older than this is not believed. The app writes the
  /// next state within seconds, so an old one means the app is gone.
  static let loadingLimit: TimeInterval = 60

  let values: [String: String]

  init(values: [String: String]) {
    self.values = values
  }

  /// The store as the app last wrote it. Empty before the app's first run.
  static func shared() -> WidgetStore {
    let defaults = UserDefaults(suiteName: appGroup)
    let keys = [
      Key.language, Key.title, Key.dates, Key.line, Key.linePauses,
      Key.lineMeaning, Key.hukamnamaMeta, Key.openLabel, Key.labels,
      Key.playback,
    ]
    var values: [String: String] = [:]
    for key in keys {
      if let value = defaults?.string(forKey: key) { values[key] = value }
    }
    return WidgetStore(values: values)
  }

  var isEmpty: Bool { values[Key.title] == nil }

  var punjabi: Bool { values[Key.language] == "pa" }

  /// The SGPC day of [date]: the day at Amritsar, as `2026-11-03`. The dates
  /// in the store use it as their key, so the date and the Hukamnama agree.
  static func sgpcDay(of date: Date) -> String {
    let format = DateFormatter()
    format.locale = Locale(identifier: "en_US_POSIX")
    format.timeZone = TimeZone(identifier: "Asia/Kolkata")
    format.dateFormat = "yyyy-MM-dd"
    return format.string(from: date)
  }

  /// The start of each SGPC day in the store after [date]. The widget draws
  /// itself again at each one, so the date moves on with the app closed.
  func dayStarts(after date: Date) -> [Date] {
    let format = DateFormatter()
    format.locale = Locale(identifier: "en_US_POSIX")
    format.timeZone = TimeZone(identifier: "Asia/Kolkata")
    format.dateFormat = "yyyy-MM-dd"
    return dates.keys.compactMap { format.date(from: $0) }
      .filter { $0 > date }
      .sorted()
  }

  /// When the picture at [date] stops being true by itself: when a "loading"
  /// state runs out. Nil when nothing runs out.
  func loadingEnds(after date: Date) -> Date? {
    guard let playback = playback, playback.state == "loading" else { return nil }
    let end = playback.at.addingTimeInterval(Self.loadingLimit)
    return end > date ? end : nil
  }

  /// What the widget shows at [date].
  func content(at date: Date) -> WidgetContent {
    let names = labels["name"] ?? [:]
    let hukamnamaName = names["hukamnama"] ?? (punjabi ? "ਹੁਕਮਨਾਮਾ" : "Hukamnama")
    let liveName = names["live"] ?? (punjabi ? "ਲਾਈਵ ਕੀਰਤਨ" : "Live Kirtan")
    let line = values[Key.line].flatMap { $0.isEmpty ? nil : $0 }
    let today = dates[Self.sgpcDay(of: date)] ?? ""
    let meta = line == nil ? today : (values[Key.hukamnamaMeta] ?? today)

    let now = believedPlayback(at: date)
    let liveState = now.source == "live" ? now.state : "idle"
    let hukamnamaState = now.source == "hukamnama" ? now.state : "idle"

    return WidgetContent(
      title: values[Key.title] ?? hukamnamaName,
      meta: meta,
      line: line,
      pauses: line == nil ? [:] : pauses,
      meaning: line == nil ? nil : values[Key.lineMeaning].flatMap {
        let text = $0.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
      },
      openLabel: values[Key.openLabel] ?? hukamnamaName,
      hukamnamaName: hukamnamaName,
      liveName: liveName,
      hukamnama: WidgetButtonState(
        icon: Self.icon(for: hukamnamaState, onIcon: .pause),
        spoken: labels["hukamnama"]?[hukamnamaState] ?? hukamnamaName
      ),
      live: WidgetButtonState(
        icon: Self.icon(for: liveState, onIcon: .stop),
        spoken: labels["live"]?[liveState] ?? liveName
      )
    )
  }

  /// Live Kirtan stops, and the Hukamnama pauses. The same rules as Android.
  private static func icon(
    for state: String,
    onIcon: WidgetButtonState.Icon
  ) -> WidgetButtonState.Icon {
    switch state {
    case "loading": return .loading
    case "playing": return onIcon
    default: return .play
    }
  }

  // MARK: - The JSON values

  /// The pauses Dart wrote, `{"1": "short", "4": "long"}`: true for a long
  /// pause. Empty when there are none or they cannot be read.
  private var pauses: [Int: Bool] {
    guard
      let text = values[Key.linePauses],
      let data = text.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else { return [:] }
    var pauses: [Int: Bool] = [:]
    for (key, kind) in json {
      guard let index = Int(key), kind == "short" || kind == "long" else { continue }
      pauses[index] = kind == "long"
    }
    return pauses
  }

  private var dates: [String: String] {
    decode(values[Key.dates]) ?? [:]
  }

  /// `name`, `live` and `hukamnama`, each a map of words. See widgetLabels.
  private var labels: [String: [String: String]] {
    decode(values[Key.labels]) ?? [:]
  }

  struct Playback {
    let state: String
    let source: String?
    let at: Date
  }

  private var playback: Playback? {
    guard
      let text = values[Key.playback],
      let data = text.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let state = json["state"] as? String
    else { return nil }
    let ms = (json["at"] as? NSNumber)?.doubleValue ?? 0
    return Playback(
      state: state,
      source: json["source"] as? String,
      at: Date(timeIntervalSince1970: ms / 1000)
    )
  }

  /// The playback to draw. A "loading" state that ran out is idle: the app
  /// that wrote it never wrote what came next.
  private func believedPlayback(at date: Date) -> Playback {
    let idle = Playback(state: "idle", source: nil, at: date)
    guard let playback = playback else { return idle }
    if playback.state == "loading",
      date.timeIntervalSince(playback.at) >= Self.loadingLimit
    {
      return idle
    }
    return playback
  }

  private func decode<T: Decodable>(_ text: String?) -> T? {
    guard let data = text?.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }
}
