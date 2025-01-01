// //
// //  KathaIntent.swift
// //  Runner
// //
// //  Created by Harkirat Singh on 1/1/2025.
// //


import AppIntents
import intelligence

struct KathaIntent: AppIntent {
  static var title: LocalizedStringResource = "Play Mukhwak Katha"
  static var openAppWhenRun: Bool = true
  
  @MainActor
  func perform() async throws -> some IntentResult {
    IntelligencePlugin.notifier.push("mukhwak_katha")
    return .result()
  }
}


struct KathaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: KathaIntent(),
      phrases: [
        "Play katha in \(.applicationName)",
        "Start katha in \(.applicationName)",
        "Play mukhwak katha in \(.applicationName)",
        "Play hukumnama katha in \(.applicationName)"
      ]
    )
  }
}
