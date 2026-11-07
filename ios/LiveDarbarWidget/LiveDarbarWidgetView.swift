import AppIntents
import SwiftUI

// The iPhone widget's picture. SwiftUI and AppIntents, with no WidgetKit, so a
// Mac script can render it for review. The rules are in docs/DESIGN.md, "Home
// screen widget", and they are the Android widget's rules.

/// The app's palette (lib/src/core/palette.dart). Dark only.
enum WidgetPalette {
  static let canvas = Color(hex: 0x0C0A09)
  static let surfaceHigh = Color(hex: 0x231D18)
  static let foreground = Color(hex: 0xF5F1EB)
  static let muted = Color(hex: 0xADA398)
  static let gold = Color(hex: 0xE8B04B)
  static let onGold = Color(hex: 0x0C0A09)
  /// The word before a short pause, and before a long one, as in the reader.
  static let pauseShort = Color(hex: 0x8FCB9B)
  static let pauseLong = Color(hex: 0xF08A5D)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}

/// The links the widget opens. lib/src/home_screen_widget/widget_links.dart
/// reads the same strings. `homeWidget` is the query item that home_widget
/// looks for before it hands a link to Dart.
enum WidgetLink {
  static let live = link("live")
  static let hukamnama = link("hukamnama")
  static let open = link("open")

  private static func link(_ part: String) -> URL {
    URL(string: "livedarbar://widget/\(part)?homeWidget")!
  }
}

/// What 1 button shows. Only the icon changes with the state. The name stays,
/// so the listener always knows which button is which.
struct WidgetButtonState: Equatable {
  enum Icon: Equatable { case play, pause, stop, loading }

  var icon: Icon
  /// The name, the state, and what a tap does: "Live kirtan, playing. Double
  /// tap to stop."
  var spoken: String
}

/// Everything the widget draws.
struct WidgetContent: Equatable {
  /// The first word of the top line: "Hukamnama".
  var title: String
  /// The rest of the top line: "3 Nov · Ang 877". The day of the line, so an
  /// old line names its own day. Today's date when there is no line.
  var meta: String
  /// The Rahao line in Gurmukhi. Nil until the app has loaded a Hukamnama.
  var line: String?
  /// The words of [line] before a pause, by index: true for a long pause.
  var pauses: [Int: Bool] = [:]
  /// The English meaning of [line], for 1 line under it.
  var meaning: String?
  /// What a screen reader says for the widget away from its buttons.
  var openLabel: String
  var hukamnamaName: String
  var liveName: String
  var hukamnama: WidgetButtonState
  var live: WidgetButtonState
}

struct LiveDarbarWidgetView: View {
  let content: WidgetContent

  /// False only for the review render on a Mac, which cannot draw a [Link].
  var links = true

  /// Tiro Gurmukhi, the app's Gurbani face. Bundled with the widget.
  static let gurbaniFont = "TiroGurmukhi-Regular"

  /// Below this content height (the medium widget of the smallest iPhones,
  /// 109 pt), the full layout cuts the Rahao line to 1 line.
  static let compactHeight: CGFloat = 120

  /// The line, with the word before each pause in its colour: green before
  /// a short pause, kesri before a long one. Words are split at white space,
  /// as Dart counts them.
  static func gurbani(_ line: String, pauses: [Int: Bool]) -> Text {
    let words = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    guard !pauses.isEmpty, !words.isEmpty else {
      return Text(line).foregroundColor(WidgetPalette.foreground)
    }
    var text = Text("")
    for (index, word) in words.enumerated() {
      if index > 0 { text = text + Text(" ") }
      let colour: Color
      switch pauses[index] {
      case .some(true): colour = WidgetPalette.pauseLong
      case .some(false): colour = WidgetPalette.pauseShort
      case .none: colour = WidgetPalette.foreground
      }
      text = text + Text(word).foregroundColor(colour)
    }
    return text
  }

  var body: some View {
    GeometryReader { space in
      layout(compact: space.size.height < Self.compactHeight)
    }
  }

  /// The widget tries the layout with the English meaning first, and keeps
  /// it only when the whole Gurbani still fits in its 2 lines. Else it shows
  /// the Gurbani alone, as before the meaning: the Gurbani is never cut to
  /// make room for the English.
  private func layout(compact: Bool) -> some View {
    ViewThatFits(in: .vertical) {
      if content.line != nil && content.meaning != nil {
        stack(compact: compact, meaning: true)
      }
      stack(compact: compact, meaning: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func stack(compact: Bool, meaning: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      topLine
      if let line = content.line {
        // Never letter spacing on Gurmukhi: it breaks the matras. The extra
        // line spacing keeps the tall matras of 2 lines from touching. Fixed
        // in height, so the layout never squeezes it to 1 cut line.
        Self.gurbani(line, pauses: content.pauses)
          .font(.custom(Self.gurbaniFont, size: compact ? 16 : 17))
          .lineSpacing(compact ? 3 : (meaning ? 4 : 6))
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, compact ? 5 : (meaning ? 6 : 8))
          .accessibilityLabel(content.openLabel)
        if meaning, let text = content.meaning {
          Text(text)
            .font(.system(size: compact ? 11 : 12))
            .foregroundColor(WidgetPalette.muted)
            .lineLimit(1)
            .padding(.top, compact ? 1 : 3)
            .accessibilityHidden(true)
        }
      }
      Spacer(minLength: compact ? 6 : (meaning ? 8 : 10))
      HStack(spacing: 8) {
        WidgetButton(
          name: content.hukamnamaName,
          state: content.hukamnama,
          gold: false,
          source: links ? .hukamnama : nil,
          height: compact ? 36 : 40
        )
        WidgetButton(
          name: content.liveName,
          state: content.live,
          gold: true,
          source: links ? .live : nil,
          height: compact ? 36 : 40
        )
      }
    }
  }


  private var topLine: some View {
    let rest = content.meta.isEmpty ? "" : " · \(content.meta)"
    let title = Text(content.title).foregroundColor(WidgetPalette.gold)
    let meta = Text(rest).foregroundColor(WidgetPalette.muted)
    return Text("\(title)\(meta)")
      .font(.system(size: 13, weight: .medium))
      .lineLimit(1)
      // 13 pt down to 11 pt before it cuts the Ang.
      .minimumScaleFactor(11.0 / 13.0)
  }
}

/// A 40 pt capsule, 36 pt on the smallest iPhones. The whole half of the
/// row is the target.
struct WidgetButton: View {
  let name: String
  let state: WidgetButtonState
  let gold: Bool
  /// Nil only for the review render.
  let source: WidgetPlaySource?
  let height: CGFloat

  /// iOS 17 and newer: a button that plays in the app's process with the app
  /// in the background (WidgetPlayIntents.swift). iOS 16: a link that opens
  /// the app, which then plays.
  @ViewBuilder var body: some View {
    if let source = source {
      if #available(iOS 17.0, *) {
        intentButton(source)
      } else {
        Link(destination: Self.url(for: source)) { label }
          .accessibilityLabel(state.spoken)
      }
    } else {
      label
    }
  }

  private static func url(for source: WidgetPlaySource) -> URL {
    switch source {
    case .live: return WidgetLink.live
    case .hukamnama: return WidgetLink.hukamnama
    }
  }

  /// A toggle, not a button. iOS draws an interactive widget again only after
  /// the tap's intent ends, and the intent waits for sound: many seconds on a
  /// slow line. But iOS flips a toggle in the widget the moment it is tapped.
  /// [PendingToggleStyle] sees that flip before the app has written anything,
  /// and shows "…" on the tapped button only.
  @available(iOS 17.0, *)
  @ViewBuilder private func intentButton(_ source: WidgetPlaySource) -> some View {
    switch source {
    case .live:
      Toggle(isOn: isOn, intent: LiveKirtanWidgetIntent()) { EmptyView() }
        .toggleStyle(PendingToggleStyle(button: self))
        .accessibilityLabel(state.spoken)
    case .hukamnama:
      Toggle(isOn: isOn, intent: HukamnamaWidgetIntent()) { EmptyView() }
        .toggleStyle(PendingToggleStyle(button: self))
        .accessibilityLabel(state.spoken)
    }
  }

  /// On while the source plays or opens, by the state the app last wrote.
  var isOn: Bool { state.icon != .play }

  private var label: some View { label(icon: state.icon) }

  func label(icon: WidgetButtonState.Icon) -> some View {
    HStack(spacing: 6) {
      iconView(icon).frame(width: 14)
      Text(name)
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
    .foregroundColor(gold ? WidgetPalette.onGold : WidgetPalette.foreground)
    .frame(maxWidth: .infinity)
    .frame(height: height)
    .background(
      Capsule().fill(gold ? WidgetPalette.gold : WidgetPalette.surfaceHigh)
    )
    // A source that is opening: a still "…", and the button dimmed. A
    // widget cannot spin.
    .opacity(icon == .loading ? 0.6 : 1)
  }

  @ViewBuilder private func iconView(_ icon: WidgetButtonState.Icon) -> some View {
    switch icon {
    case .loading:
      Text("…").font(.system(size: 14, weight: .semibold))
    case .play:
      Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
    case .pause:
      Image(systemName: "pause.fill").font(.system(size: 12, weight: .bold))
    case .stop:
      Image(systemName: "stop.fill").font(.system(size: 12, weight: .bold))
    }
  }
}

/// Draws a widget button from its toggle. iOS sets `isOn` the moment the
/// listener taps. When that differs from the state the app last wrote, the
/// tap is still running, so this button alone shows "…" until the app writes
/// the new state and iOS draws the widget again.
@available(iOS 17.0, macOS 14.0, *)
struct PendingToggleStyle: ToggleStyle {
  let button: WidgetButton

  func makeBody(configuration: Configuration) -> some View {
    let pending = configuration.isOn != button.isOn
    return button.label(icon: pending ? .loading : button.state.icon)
  }
}
