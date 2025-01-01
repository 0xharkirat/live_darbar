import AppIntents
import intelligence

struct MukhwakIntent: AppIntent {
  static var title: LocalizedStringResource = "Play Mukhwak"
  static var openAppWhenRun: Bool = true
  
  @MainActor
  func perform() async throws -> some IntentResult {
    IntelligencePlugin.notifier.push("mukhwak")
    return .result()
  }
}

struct MukhwakShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: MukhwakIntent(),
      phrases: [
        "Play mukhwak in \(.applicationName)",
        "Start hukumnama in \(.applicationName)"
      ]
    )
  }
}