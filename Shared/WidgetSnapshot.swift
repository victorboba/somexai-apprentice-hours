import Foundation

/// A tiny summary the app writes to the shared App Group so the widget can render
/// without touching SwiftData.
struct WidgetSnapshot: Codable {
    var totalOJT: Double = 0
    var requiredOJT: Double = 0
    var periodHours: Double = 0
    var periodLabel: String = ""
    var unsignedHours: Double = 0
    var weakestCategory: String?
    var updatedAt: Date = .now

    var fraction: Double { requiredOJT > 0 ? min(totalOJT / requiredOJT, 1) : 0 }

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    static let placeholder = WidgetSnapshot(totalOJT: 4820, requiredOJT: 8000, periodHours: 152,
                                            periodLabel: "September", unsignedHours: 32,
                                            weakestCategory: "Motors and controls")
}
