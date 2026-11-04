import SwiftUI
import WidgetKit

/// The iPhone home screen widget: today's Hukamnama, with a Hukamnama button
/// and a Live Kirtan button. 1 size, medium, like the Android widget.
///
/// On iOS 17 and newer, each button is an App Intent that plays, pauses or
/// stops in the app's process, with the app in the background. See
/// ios/Runner/WidgetPlayIntents.swift. On iOS 16, and for the part of the
/// widget away from its buttons, each part is a link that opens the app. See
/// lib/src/home_screen_widget/widget_links.dart.
@main
struct LiveDarbarWidgetBundle: WidgetBundle {
  var body: some Widget {
    LiveDarbarWidget()
  }
}

struct LiveDarbarWidget: Widget {
  /// kIosWidgetKind in widget_data.dart. The app reloads the widget by it.
  static let kind = "LiveDarbarWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: Provider()) { entry in
      LiveDarbarWidgetView(content: entry.content)
        .widgetURL(WidgetLink.open)
        .widgetBackground(WidgetPalette.canvas)
    }
    .configurationDisplayName("Live Darbar")
    .description("Today's Hukamnama, with buttons for the Hukamnama and Live Kirtan.")
    .supportedFamilies([.systemMedium])
  }
}

struct Entry: TimelineEntry {
  let date: Date
  let content: WidgetContent
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry {
    Entry(date: Date(), content: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    let store = WidgetStore.shared()
    let now = Date()
    // The widget gallery shows a sample before the app's first run.
    completion(Entry(date: now, content: store.isEmpty ? .sample : store.content(at: now)))
  }

  /// 1 entry now, 1 at the start of each SGPC day the store has a date for,
  /// and 1 when a "loading" state runs out. The app reloads the timeline each
  /// time it writes.
  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let store = WidgetStore.shared()
    let now = Date()
    var times = [now] + store.dayStarts(after: now)
    if let end = store.loadingEnds(after: now) { times.append(end) }
    let entries = times.sorted().map { Entry(date: $0, content: store.content(at: $0)) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

extension WidgetContent {
  /// What the widget gallery shows before the app has written anything.
  static let sample = WidgetContent(
    title: "Hukamnama",
    meta: "Ang 1",
    line: "ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ",
    openLabel: "Read today's Hukamnama",
    hukamnamaName: "Hukamnama",
    liveName: "Live Kirtan",
    hukamnama: WidgetButtonState(icon: .play, spoken: "Hukamnama"),
    live: WidgetButtonState(icon: .play, spoken: "Live Kirtan")
  )
}

extension View {
  /// iOS 17 draws the background behind the content margins. iOS 16 needs
  /// the padding and the background from the view.
  @ViewBuilder
  func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      padding().background(color)
    }
  }
}
