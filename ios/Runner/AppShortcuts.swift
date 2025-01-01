import AppIntents
import intelligence

struct AppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    [
      // Mukhwak Intent
      AppShortcut(
        intent: MukhwakIntent(),
        phrases: [
          "Play mukhwak in \(.applicationName)",
          "Start hukumnama in \(.applicationName)"
        ]
      ),
      
      // Live Kirtan Intent
      AppShortcut(
        intent: LiveKirtanIntent(),
        phrases: [
          "Play Live Kirtan in \(.applicationName)",
          "Start Live Kirtan in \(.applicationName)",
          "Open \(.applicationName)"
        ]
      ),
      
      // Katha Intent
      AppShortcut(
        intent: KathaIntent(),
        phrases: [
          "Play katha in \(.applicationName)",
          "Start katha in \(.applicationName)",
          "Play mukhwak katha in \(.applicationName)",
          "Play hukumnama katha in \(.applicationName)"
        ]
      )
    ]
  }
}
