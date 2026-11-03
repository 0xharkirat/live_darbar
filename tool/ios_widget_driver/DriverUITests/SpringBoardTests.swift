import XCTest

// Drives SpringBoard, the iOS home screen, so a Mac can press the real widget.
// run.sh builds and runs these. They write screenshots and the accessibility
// tree to `out`, for a person to look at when a step breaks.

let out = "/tmp/live_darbar_widget_driver"

func save(_ name: String, _ app: XCUIApplication) {
  try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
  let shot = XCUIScreen.main.screenshot().pngRepresentation
  try? shot.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
  try? app.debugDescription.write(toFile: "\(out)/\(name).txt", atomically: true, encoding: .utf8)
}

final class SpringBoardTests: XCTestCase {
  let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")

  override func setUp() { continueAfterFailure = false }

  /// Home, first page, no edit mode.
  private func resetHome() {
    XCUIDevice.shared.press(.home)
    sleep(1)
    XCUIDevice.shared.press(.home)
    sleep(1)
    let done = sb.buttons["Done"].firstMatch
    if done.exists { done.tap(); sleep(1) }
  }

  private func button(_ label: String) -> XCUIElement {
    sb.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
  }

  /// Swipes through the home pages until [element] shows.
  private func scrollTo(_ element: XCUIElement) {
    for _ in 0..<3 {
      if element.exists { return }
      sb.swipeLeft()
      sleep(1)
    }
  }

  /// Puts the Live Darbar widget on the home screen, from the gallery.
  func testAddWidget() throws {
    resetHome()
    sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: 1.5)
    sleep(1)
    sb.buttons["Edit"].firstMatch.tap()
    sleep(1)
    sb.buttons["Add Widget"].firstMatch.tap()
    sleep(2)
    let search = sb.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5), "no widget gallery")
    search.tap()
    search.typeText("Live Darbar")
    sleep(2)
    save("add_search", sb)
    // The only row. The app's name, under the search field.
    sb.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.29)).tap()
    sleep(2)
    save("add_detail", sb)
    // The label has a leading space: " Add Widget".
    let add = button("Add Widget")
    XCTAssertTrue(add.waitForExistence(timeout: 5), "no Add Widget button")
    add.tap()
    sleep(2)
    sb.buttons["Done"].firstMatch.tap()
    sleep(2)
    save("add_done", sb)
  }

  /// Taps the widget button whose accessibility label has the words in
  /// `target.txt`: `live kirtan` or `hukamnama`. The label says the state,
  /// so the file's words must be in every state's label.
  func testTapTarget() throws {
    let target =
      (try? String(contentsOfFile: "\(out)/target.txt", encoding: .utf8))?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? "live kirtan"
    resetHome()
    let widgetButton = button(target)
    scrollTo(widgetButton)
    XCTAssertTrue(widgetButton.waitForExistence(timeout: 5), "no \(target) button on the home screen")
    try? widgetButton.label.write(toFile: "\(out)/tapped_label.txt", atomically: true, encoding: .utf8)
    widgetButton.tap()
    sleep(14)
    save("tap_after", sb)
  }

  /// A long press on the app icon, then the Live Kirtan quick action.
  func testQuickAction() throws {
    resetHome()
    scrollTo(button("live kirtan"))
    // The app icon, at the right of the 2nd icon row below the widget.
    sb.coordinate(withNormalizedOffset: CGVector(dx: 0.845, dy: 0.488)).press(forDuration: 1.5)
    sleep(1)
    save("quick_menu", sb)
    let item = sb.buttons.matching(NSPredicate(format: "label == 'Live Kirtan'")).firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 5), "no quick action")
    item.tap()
    sleep(12)
    save("quick_after", sb)
  }
}
