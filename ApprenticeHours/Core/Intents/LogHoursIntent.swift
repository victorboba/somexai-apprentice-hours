import AppIntents
import Foundation

/// "Log hours in Apprentice Hours" from Siri, Spotlight or Shortcuts.
struct LogHoursIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Hours"
    static var description = IntentDescription("Opens Apprentice Hours ready to record a day.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.logHours"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct ApprenticeHoursShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogHoursIntent(),
            phrases: ["Log hours in \(.applicationName)", "Add a day to \(.applicationName)"],
            shortTitle: "Log Hours",
            systemImageName: "clock.fill"
        )
    }
}
