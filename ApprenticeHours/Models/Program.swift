import Foundation
import SwiftData

/// The trade, used only to offer a starting set of work categories. The programme's real
/// requirements always come from the apprentice's own standards, not from this list.
enum Trade: String, Codable, CaseIterable, Identifiable {
    case electrical, plumbing, hvac, sheetMetal, pipefitting, carpentry, millwright, other
    var id: String { rawValue }

    var name: String {
        switch self {
        case .electrical: return "Electrical"
        case .plumbing: return "Plumbing"
        case .hvac: return "HVAC/R"
        case .sheetMetal: return "Sheet metal"
        case .pipefitting: return "Pipefitting"
        case .carpentry: return "Carpentry"
        case .millwright: return "Millwright"
        case .other: return "Other trade"
        }
    }

    var symbol: String {
        switch self {
        case .electrical: return "bolt.fill"
        case .plumbing: return "drop.fill"
        case .hvac: return "wind"
        case .sheetMetal: return "square.stack.3d.up.fill"
        case .pipefitting: return "pipe.and.drop.fill"
        case .carpentry: return "hammer.fill"
        case .millwright: return "gearshape.2.fill"
        case .other: return "wrench.and.screwdriver.fill"
        }
    }

    /// Offered when a programme is created so the apprentice is not typing twelve categories from
    /// a blank screen. Every name and every hour figure is theirs to change.
    var starterCategories: [(String, Double)] {
        switch self {
        case .electrical:
            return [("Conduit and raceway", 1000), ("Wire pulling and terminations", 1000),
                    ("Panels, switchgear and services", 800), ("Lighting", 600),
                    ("Motors and controls", 600), ("Fire alarm and low voltage", 400),
                    ("Troubleshooting and service", 800), ("Grounding and bonding", 300)]
        case .plumbing:
            return [("DWV rough-in", 1000), ("Water supply rough-in", 1000),
                    ("Fixture setting and trim", 800), ("Gas piping", 500),
                    ("Water heaters", 400), ("Drain cleaning and service", 800),
                    ("Backflow and testing", 300)]
        case .hvac:
            return [("Sheet metal and duct", 800), ("Refrigerant piping", 800),
                    ("Equipment set and start-up", 800), ("Electrical and controls", 700),
                    ("Service and troubleshooting", 1000), ("Air balance and testing", 400)]
        case .sheetMetal:
            return [("Layout and fabrication", 1000), ("Duct installation", 1000),
                    ("Welding and brazing", 500), ("Architectural sheet metal", 600),
                    ("Testing and balancing", 500), ("Service", 600)]
        case .pipefitting:
            return [("Pipe fabrication", 1000), ("Welding", 1000), ("Rigging and hoisting", 400),
                    ("Steam and hydronic", 800), ("Testing and commissioning", 500)]
        case .carpentry:
            return [("Framing", 1000), ("Concrete and formwork", 800), ("Finish carpentry", 800),
                    ("Doors and hardware", 400), ("Layout", 500), ("Scaffolding and safety", 300)]
        case .millwright:
            return [("Rigging and moving", 800), ("Alignment", 800), ("Bearings and drives", 700),
                    ("Pumps and compressors", 700), ("Welding and fabrication", 600), ("Precision measurement", 400)]
        case .other:
            return []
        }
    }
}

/// How often the sponsor wants a report.
enum ReportPeriod: String, Codable, CaseIterable, Identifiable {
    case monthly, quarterly, semiannual, annual
    var id: String { rawValue }

    var name: String {
        switch self {
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .semiannual: return "Every 6 months"
        case .annual: return "Annually"
        }
    }

    /// The heading on the Progress tab, which reads better than "Monthly period".
    var currentLabel: String {
        switch self {
        case .monthly: return "This month"
        case .quarterly: return "This quarter"
        case .semiannual: return "This period"
        case .annual: return "This year"
        }
    }

    var months: Int {
        switch self {
        case .monthly: return 1
        case .quarterly: return 3
        case .semiannual: return 6
        case .annual: return 12
        }
    }
}

/// The apprenticeship itself. Every requirement in here is typed in from the apprentice's own
/// standards of apprenticeship; the app never asserts what any state or sponsor requires.
@Model
final class Program {
    var id: UUID = UUID()
    var apprenticeName: String = ""
    var apprenticeNumber: String = ""
    var tradeRaw: String = Trade.electrical.rawValue
    var sponsor: String = ""
    var programNumber: String = ""
    var startDate: Date = Date()
    /// Total on-the-job hours the programme requires.
    var requiredOJT: Double = 8000
    /// Related instruction (classroom) hours the programme requires in total.
    var requiredInstruction: Double = 900
    /// Hours credited before the app was installed, so the totals are not wrong from day one.
    var priorOJT: Double = 0
    var priorInstruction: Double = 0
    var periodRaw: String = ReportPeriod.monthly.rawValue
    var createdAt: Date = Date()

    init(apprenticeName: String = "", trade: Trade = .electrical) {
        self.id = UUID()
        self.apprenticeName = apprenticeName
        self.tradeRaw = trade.rawValue
        self.createdAt = .now
    }
}

extension Program {
    var trade: Trade {
        get { Trade(rawValue: tradeRaw) ?? .electrical }
        set { tradeRaw = newValue.rawValue }
    }

    var period: ReportPeriod {
        get { ReportPeriod(rawValue: periodRaw) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    var displayName: String {
        let trimmed = apprenticeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Apprentice" : trimmed
    }
}

/// One work process with its own required minimum. Sponsors differ, so these are the apprentice's own.
@Model
final class WorkCategory {
    var id: UUID = UUID()
    var programID: UUID = UUID()
    var name: String = ""
    /// Hours the programme requires in this category. Zero means it is tracked without a minimum.
    var requiredHours: Double = 0
    var priorHours: Double = 0
    var sortIndex: Int = 0
    var archived: Bool = false
    var createdAt: Date = Date()

    init(programID: UUID, name: String = "", requiredHours: Double = 0, sortIndex: Int = 0) {
        self.id = UUID()
        self.programID = programID
        self.name = name
        self.requiredHours = requiredHours
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}

extension WorkCategory {
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Work process" : trimmed
    }
}
