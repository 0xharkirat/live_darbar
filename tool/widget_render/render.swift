import AppKit
import SwiftUI

// Draws the iPhone widget as pictures, for the "add the widget" card and its
// steps sheet. It is the real SwiftUI view (ios/LiveDarbarWidget), idle, on a
// Mac. Run tool/widget_render/run.sh.
//
// The words are what the app writes to the widget's store for the recorded
// 2 November 2026 Hukamnama (test/fixtures), in each language. Change them
// here when the widget's words change, then run the script again.

@main
struct Render {
  /// A medium widget on an iPhone 15 Pro: 338 x 158 pt, with 16 pt of margin.
  static let size = CGSize(width: 338, height: 158)
  static let margin: CGFloat = 16
  static let corner: CGFloat = 22

  static let line = "ਜਿਉ ਬਿਨੁ ਅਮਲੈ ਅਮਲੀ ਮਰਿ ਜਾਈ ਹੈ ਤਿਉ ਹਰਿ ਬਿਨੁ ਹਮ ਮਰਿ ਜਾਤੀ ॥ ਰਹਾਉ ॥"

  static let stores: [(language: String, values: [String: String])] = [
    (
      "en",
      [
        WidgetStore.Key.language: "en",
        WidgetStore.Key.title: "Hukamnama",
        WidgetStore.Key.line: line,
        WidgetStore.Key.hukamnamaMeta: "2 Nov · Ang 668",
        WidgetStore.Key.labels:
          #"{"name":{"live":"Live Kirtan","hukamnama":"Hukamnama"}}"#,
      ]
    ),
    (
      "pa",
      [
        WidgetStore.Key.language: "pa",
        WidgetStore.Key.title: "ਹੁਕਮਨਾਮਾ",
        WidgetStore.Key.line: line,
        WidgetStore.Key.hukamnamaMeta: "੨ ਨਵੰ · ਅੰਗ ੬੬੮",
        WidgetStore.Key.labels:
          #"{"name":{"live":"ਲਾਈਵ ਕੀਰਤਨ","hukamnama":"ਹੁਕਮਨਾਮਾ"}}"#,
      ]
    ),
  ]

  /// render <font file> <output folder>
  @MainActor static func main() {
    let args = CommandLine.arguments
    guard args.count == 3 else {
      print("usage: render <TiroGurmukhi-400.ttf> <output folder>")
      exit(2)
    }
    var error: Unmanaged<CFError>?
    let fontURL = URL(fileURLWithPath: args[1]) as CFURL
    guard CTFontManagerRegisterFontsForURL(fontURL, .process, &error) else {
      print("The font did not load: \(String(describing: error))")
      exit(1)
    }
    let out = URL(fileURLWithPath: args[2], isDirectory: true)
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

    for (language, values) in stores {
      let content = WidgetStore(values: values).content(at: Date())
      let picture = LiveDarbarWidgetView(content: content, links: false)
        .padding(margin)
        .frame(width: size.width, height: size.height)
        .background(WidgetPalette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .environment(\.colorScheme, .dark)

      let renderer = ImageRenderer(content: picture)
      renderer.scale = 3
      guard
        let image = renderer.nsImage,
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
      else {
        print("Could not draw \(language)")
        exit(1)
      }
      let file = out.appendingPathComponent("widget_idle_\(language).png")
      try! png.write(to: file)
      print("wrote \(file.path)")
    }
  }
}
