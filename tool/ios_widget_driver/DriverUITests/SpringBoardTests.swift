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

  // MARK: - The film
  //
  // testFilm adds the widget and plays Live Kirtan from it at a calm pace, for
  // a screen recording (see run.sh film). It writes one line for each tap to
  // `film_taps.jsonl`: the Mac's clock, the place as fractions of the screen,
  // and how long a press was held. The film is cut from the recording, and the
  // tap marks that the app draws over it come from those lines.

  private var tapLog: String { "\(out)/film_taps.jsonl" }

  private func logTap(_ id: String, x: Double, y: Double, hold: Double = 0) {
    let t = Date().timeIntervalSince1970
    let line = String(
      format: "{\"id\":\"%@\",\"t\":%.3f,\"x\":%.4f,\"y\":%.4f,\"hold\":%.2f}\n",
      id, t, x, y, hold)
    if let h = FileHandle(forWritingAtPath: tapLog) {
      h.seekToEndOfFile()
      h.write(line.data(using: .utf8)!)
      h.closeFile()
    } else {
      try? line.write(toFile: tapLog, atomically: true, encoding: .utf8)
    }
  }

  /// The pause between 2 steps. A person watching needs it, and the film's cut
  /// keeps it.
  private func beat(_ seconds: Double = 0.7) { usleep(UInt32(seconds * 1_000_000)) }

  /// Taps [element] where its middle is, and logs the tap just before.
  private func film(tap id: String, _ element: XCUIElement) {
    let f = element.frame
    let size = sb.frame.size
    let x = Double(f.midX / size.width)
    let y = Double(f.midY / size.height)
    film(tap: id, x: x, y: y)
  }

  private func film(tap id: String, x: Double, y: Double) {
    let c = sb.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    logTap(id, x: x, y: y)
    c.tap()
  }

  /// A file the shell script writes, to say the recording has started.
  private func waitForFile(_ name: String, timeout: TimeInterval) {
    let path = "\(out)/\(name)"
    let end = Date().addingTimeInterval(timeout)
    while !FileManager.default.fileExists(atPath: path) && Date() < end { usleep(100_000) }
  }

  private func mark(_ name: String) {
    try? "\(Date().timeIntervalSince1970)".write(
      toFile: "\(out)/\(name)", atomically: true, encoding: .utf8)
  }

  /// Gets the phone ready for the film: the app in English, so the widget is
  /// in English, and the app closed.
  func testPrepare() throws {
    let app = XCUIApplication(bundleIdentifier: "com.hsiharki.liveDarbar")
    app.launch()
    // The label is "Change language: English", in the language of the app.
    let english = app.buttons.matching(NSPredicate(format: "label ENDSWITH 'English'")).firstMatch
    let found = english.waitForExistence(timeout: 15)
    save("prepare_app", app)
    XCTAssertTrue(found, "no language switch")
    english.tap()
    sleep(5)
    app.terminate()
    resetHome()
    save("prepare_home", sb)
  }

  /// Takes the Live Darbar widget off the home screen, if it is there. It
  /// looks on the first page only, where the film puts it.
  func testRemoveWidget() throws {
    resetHome()
    let widget = widgetButton("live kirtan")
    guard widget.exists else { return }
    // The widget's text, away from its buttons.
    sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).press(forDuration: 1.2)
    let remove = button("Remove Widget")
    XCTAssertTrue(remove.waitForExistence(timeout: 5), "no Remove Widget")
    remove.tap()
    let confirm = sb.buttons.matching(NSPredicate(format: "label == 'Remove'")).firstMatch
    XCTAssertTrue(confirm.waitForExistence(timeout: 5), "no Remove")
    confirm.tap()
    sleep(1)
    let done = sb.buttons["Done"].firstMatch
    if done.exists { done.tap(); sleep(1) }
    save("remove_done", sb)
  }

  /// A widget button. iOS 26 reports a widget's buttons as switches.
  private func widgetButton(_ words: String) -> XCUIElement {
    let p = NSPredicate(format: "label CONTAINS[c] %@", words)
    let sw = sb.switches.matching(p).firstMatch
    return sw.exists ? sw : button(words)
  }

  /// The film: press and hold, Edit, Add Widget, search, the widget, Add
  /// Widget, Done, then Live Kirtan from the widget, with the app closed.
  ///
  /// Each tap is at a place that the first run read from the screen, so the
  /// steps do not wait for the accessibility tree: a query on the home
  /// screen takes 1 to 2 s, and a viewer would watch the phone stand still.
  /// The widget gallery has 1 size, medium, so there is no size to pick.
  func testFilm() throws {
    try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
    try? FileManager.default.removeItem(atPath: tapLog)
    for f in ["film_ready", "film_go", "film_end"] {
      try? FileManager.default.removeItem(atPath: "\(out)/\(f)")
    }
    resetHome()
    XCTAssertFalse(widgetButton("live kirtan").exists, "a Live Darbar widget is already on the home screen")
    // The recording starts here. The shell script answers with film_go.
    mark("film_ready")
    waitForFile("film_go", timeout: 60)
    beat(1.0)

    // 1. Press and hold an empty spot.
    let hold = 1.0
    logTap("hold", x: 0.5, y: 0.55, hold: hold)
    sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).press(forDuration: hold)
    beat(0.5)

    // 2. Edit, then Add Widget.
    film(tap: "edit", x: 0.1791, y: 0.0378)
    beat(0.7)
    film(tap: "addwidget", x: 0.3997, y: 0.1064)
    beat(1.0)

    // 3. Search for Live Darbar.
    film(tap: "search", x: 0.5, y: 0.2014)
    beat(0.6)
    sb.searchFields.firstMatch.typeText("Live Darbar")
    beat(0.9)

    // 4. The app's row, then Add Widget.
    film(tap: "row", x: 0.35, y: 0.29)
    beat(1.2)
    film(tap: "add", x: 0.5, y: 0.905)
    beat(1.0)

    // 5. Done.
    film(tap: "done", x: 0.8209, y: 0.0378)
    beat(1.0)

    // 6. Live Kirtan, from the widget, with the app closed.
    film(tap: "live", x: 0.7005, y: 0.2475)
    // Wait for the stop state: the label says it plays.
    let end = Date().addingTimeInterval(40)
    var label = ""
    while Date() < end {
      label = widgetButton("live kirtan").label
      if label.lowercased().contains("playing") { break }
      usleep(200_000)
    }
    try? label.write(toFile: "\(out)/film_final_label.txt", atomically: true, encoding: .utf8)
    mark("film_end")
    beat(2.5)
    save("film_playing", sb)
    // Stop it, after the recording.
    widgetButton("live kirtan").tap()
    sleep(2)
  }

  /// The last part of the film alone, with the widget already on the home
  /// screen: Live Kirtan from the widget, with the app closed. The widget
  /// sometimes drew its idle state again for a few seconds after it played,
  /// so this part can be taken again and joined to the first part, where the
  /// home screen stands still.
  func testFilmLive() throws {
    try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
    try? FileManager.default.removeItem(atPath: tapLog)
    for f in ["film_ready", "film_go", "film_end"] {
      try? FileManager.default.removeItem(atPath: "\(out)/\(f)")
    }
    resetHome()
    mark("film_ready")
    waitForFile("film_go", timeout: 60)
    beat(1.0)
    film(tap: "live", x: 0.7005, y: 0.2475)
    let end = Date().addingTimeInterval(40)
    var label = ""
    while Date() < end {
      label = widgetButton("live kirtan").label
      if label.lowercased().contains("playing") { break }
      usleep(200_000)
    }
    try? label.write(toFile: "\(out)/film_final_label.txt", atomically: true, encoding: .utf8)
    mark("film_end")
    beat(4.0)
    // Stop it, after the recording.
    widgetButton("live kirtan").tap()
    sleep(2)
  }

  /// Opens the app's "add the widget" steps sheet from About, and stays 12 s,
  /// so a recording can show the film play in it. It writes `sheet_open` when
  /// the sheet is up.
  func testOpenWidgetSheet() throws {
    try? FileManager.default.removeItem(atPath: "\(out)/sheet_open")
    let app = XCUIApplication(bundleIdentifier: "com.hsiharki.liveDarbar")
    app.launch()
    func find(_ words: String) -> XCUIElement {
      app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS[c] %@", words)).firstMatch
    }
    // A build made with DEMO_OFFER_UPDATE opens with the update sheet.
    let notNow = app.buttons["Not now"].firstMatch
    if notNow.waitForExistence(timeout: 15) { notNow.tap(); sleep(1) }
    let about = find("About this app")
    for _ in 0..<6 where !about.exists { app.swipeUp(); sleep(1) }
    save("sheet_home", app)
    XCTAssertTrue(about.waitForExistence(timeout: 20), "no About link")
    about.tap()
    let row = find("Home screen widget")
    XCTAssertTrue(row.waitForExistence(timeout: 10), "no widget row")
    save("sheet_about", app)
    row.tap()
    sleep(2)
    mark("sheet_open")
    save("sheet_open", app)
    sleep(12)
    save("sheet_later", app)
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
