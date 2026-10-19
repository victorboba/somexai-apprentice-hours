import Foundation
import SwiftData

#if DEBUG
/// Two and a half years of an electrical apprenticeship, used for screenshots and manual testing.
enum SampleData {
    static func insert(into context: ModelContext) {
        let calendar = Calendar.current
        let program = Program(apprenticeName: "Marcus Reed", trade: .electrical)
        program.apprenticeNumber = "EA-20341"
        program.sponsor = "Local 26 JATC"
        program.programNumber = "2019-NC-0114"
        program.startDate = calendar.date(byAdding: .month, value: -31, to: .now) ?? .now
        program.requiredOJT = 8000
        program.requiredInstruction = 900
        program.priorOJT = 0
        program.priorInstruction = 0
        program.period = .monthly
        context.insert(program)

        // Weights decide how the hours spread, so some processes end up short and the app has
        // something useful to say on the Progress tab.
        let seeds: [(String, Double, Double)] = [
            ("Conduit and raceway", 1000, 0.22),
            ("Wire pulling and terminations", 1000, 0.20),
            ("Panels, switchgear and services", 800, 0.14),
            ("Lighting", 600, 0.12),
            ("Motors and controls", 600, 0.05),
            ("Fire alarm and low voltage", 400, 0.04),
            ("Troubleshooting and service", 800, 0.18),
            ("Grounding and bonding", 300, 0.05),
        ]
        var categories: [WorkCategory] = []
        for (index, seed) in seeds.enumerated() {
            let category = WorkCategory(programID: program.id, name: seed.0, requiredHours: seed.1, sortIndex: index)
            context.insert(category)
            categories.append(category)
        }

        var generator = SystemRandomNumberGenerator()
        let sites = ["Midtown Tower", "Riverside Clinic", "Warehouse 12", "Oak Street Retrofit", "Civic Center"]
        let foremen = ["D. Whitaker", "S. Nguyen", "R. Delgado"]
        var site = sites[0]
        var foreman = foremen[0]

        // 130 weeks back to today. Everything older than last month is signed, which is what a
        // real log looks like the week a report is due.
        let signedCutoff = calendar.date(byAdding: .month, value: -1, to: .now) ?? .now
        for weekOffset in stride(from: 129, through: 0, by: -1) {
            guard let weekDay = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: .now) else { continue }
            if weekOffset % 17 == 0 { continue }                       // the odd week laid off or on holiday
            if weekOffset % 9 == 0 {                                    // new job every couple of months
                site = sites.randomElement(using: &generator) ?? site
                foreman = foremen.randomElement(using: &generator) ?? foreman
            }
            let daysThisWeek = Int.random(in: 4...5, using: &generator)
            for day in 0..<daysThisWeek {
                guard let date = calendar.date(byAdding: .day, value: day, to: startOfWeek(weekDay, calendar)),
                      date <= .now else { continue }
                let category = weighted(seeds, categories, using: &generator)
                let entry = WorkEntry(programID: program.id, category: category, date: date,
                                      hours: [8, 8, 8, 8, 10, 6, 9].randomElement(using: &generator) ?? 8)
                entry.jobSite = site
                entry.supervisor = foreman
                if date < signedCutoff {
                    entry.signedAt = calendar.date(byAdding: .day, value: 7, to: date)
                    entry.signedBy = foreman
                }
                context.insert(entry)
            }
        }

        let topics = ["Code update, Article 250", "Conduit bending lab", "Motor controls", "Blueprint reading",
                      "OSHA 30", "Transformers", "Fire alarm systems", "Grounding and bonding"]
        for monthOffset in stride(from: 30, through: 0, by: -1) {
            guard let month = calendar.date(byAdding: .month, value: -monthOffset, to: .now) else { continue }
            if calendar.component(.month, from: month) == 7 { continue }   // school is out in July
            for session in 0..<2 {
                guard let date = calendar.date(bySetting: .day, value: 6 + session * 14, of: month), date <= .now else { continue }
                let entry = ClassEntry(programID: program.id, date: date,
                                       hours: [3, 3, 4].randomElement(using: &generator) ?? 3,
                                       topic: topics.randomElement(using: &generator) ?? topics[0])
                entry.instructor = ["T. Baxter", "L. Okafor"].randomElement(using: &generator) ?? "T. Baxter"
                context.insert(entry)
            }
        }
        try? context.save()
    }

    private static func startOfWeek(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private static func weighted(_ seeds: [(String, Double, Double)], _ categories: [WorkCategory],
                                 using generator: inout SystemRandomNumberGenerator) -> WorkCategory {
        let roll = Double.random(in: 0...1, using: &generator)
        var running = 0.0
        for (index, seed) in seeds.enumerated() {
            running += seed.2
            if roll <= running { return categories[index] }
        }
        return categories[0]
    }
}
#endif
