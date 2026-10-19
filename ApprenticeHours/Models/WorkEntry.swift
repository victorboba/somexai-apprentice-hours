import Foundation
import SwiftData

/// One day's on-the-job hours against one work process. The category name is snapshotted so
/// renaming a work process never rewrites hours already signed for.
@Model
final class WorkEntry {
    var id: UUID = UUID()
    var programID: UUID = UUID()
    var categoryID: UUID = UUID()
    var categoryName: String = ""
    var date: Date = Date()
    var hours: Double = 0
    var jobSite: String = ""
    var supervisor: String = ""
    var notes: String = ""
    /// Set when the supervising journeyman signs the period off.
    var signedAt: Date?
    var signedBy: String = ""

    init(programID: UUID, category: WorkCategory, date: Date = .now, hours: Double = 0) {
        self.id = UUID()
        self.programID = programID
        self.categoryID = category.id
        self.categoryName = category.displayName
        self.date = date
        self.hours = hours
    }
}

extension WorkEntry {
    var day: Date { Calendar.current.startOfDay(for: date) }
    var isSigned: Bool { signedAt != nil }
}

/// One session of related instruction: class, night school, online module, upgrade training.
@Model
final class ClassEntry {
    var id: UUID = UUID()
    var programID: UUID = UUID()
    var date: Date = Date()
    var hours: Double = 0
    var topic: String = ""
    var instructor: String = ""
    var notes: String = ""

    init(programID: UUID, date: Date = .now, hours: Double = 0, topic: String = "") {
        self.id = UUID()
        self.programID = programID
        self.date = date
        self.hours = hours
        self.topic = topic
    }
}

extension ClassEntry {
    var day: Date { Calendar.current.startOfDay(for: date) }
    var displayTopic: String {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Related instruction" : trimmed
    }
}
