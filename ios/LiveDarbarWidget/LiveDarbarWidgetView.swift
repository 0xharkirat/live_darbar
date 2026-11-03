import SwiftUI

// The iPhone widget's picture. Plain SwiftUI, with no WidgetKit, so a Mac
// script can render it for review. The rules are in docs/DESIGN.md, "Home
// screen widget", and they are the Android widget's rules.

/// The app's palette (lib/src/core/palette.dart). Dark only.
enum WidgetPalette {
  static let canvas = Color(hex: 0x0C0A09)
  static let surfaceHigh = Color(hex: 0x231D18)
  static let foreground = Color(hex: 0xF5F1EB)
  static let muted = Color(hex: 0xADA398)
  static let gold = Color(hex: 0xE8B04B)
  static let onGold = Color(hex: 0x0C0A09)
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

  var body: some View {
    GeometryReader { space in
      layout(compact: space.size.height < Self.compactHeight)
    }
  }

  private func layout(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      topLine
      if let line = content.line {
        // Never letter spacing on Gurmukhi: it breaks the matras. The extra
        // line spacing keeps the tall matras of 2 lines from touching.
        Text(line)
          .font(.custom(Self.gurbaniFont, size: compact ? 16 : 17))
          .foregroundColor(WidgetPalette.foreground)
          .lineSpacing(compact ? 3 : 6)
          .lineLimit(2)
          .padding(.top, compact ? 5 : 8)
          .accessibilityLabel(content.openLabel)
      }
      Spacer(minLength: compact ? 6 : 10)
      HStack(spacing: 8) {
        WidgetButton(
          name: content.hukamnamaName,
          state: content.hukamnama,
          gold: false,
          url: links ? WidgetLink.hukamnama : nil,
          height: compact ? 36 : 40
        )
        WidgetButton(
          name: content.liveName,
          state: content.live,
          gold: true,
          url: links ? WidgetLink.live : nil,
          height: compact ? 36 : 40
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
  let url: URL?
  let height: CGFloat

  var body: some View {
    if let url = url {
      Link(destination: url) { label }.accessibilityLabel(state.spoken)
    } else {
      label
    }
  }

  private var label: some View {
    HStack(spacing: 6) {
      icon.frame(width: 14)
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
    .opacity(state.icon == .loading ? 0.6 : 1)
  }

  @ViewBuilder private var icon: some View {
    switch state.icon {
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
