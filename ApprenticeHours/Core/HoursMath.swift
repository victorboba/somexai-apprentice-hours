import Foundation

/// Every total and projection the app reports, with no SwiftData dependency so it can be tested
/// directly. Nothing here decides what a programme requires: it counts hours against the numbers
/// the apprentice entered from their own standards.
enum HoursMath {

    // MARK: Filtering

    static func entries(_ entries: [WorkEntry], in programID: UUID) -> [WorkEntry] {
        entries.filter { $0.programID == programID }
    }

    static func entries(_ entries: [WorkEntry], from start: Date, to end: Date) -> [WorkEntry] {
        let calendar = Calendar.current
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        return entries.filter { $0.date >= lower && $0.date < upper }
    }

    static func classes(_ classes: [ClassEntry], from start: Date, to end: Date) -> [ClassEntry] {
        let calendar = Calendar.current
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        return classes.filter { $0.date >= lower && $0.date < upper }
    }

    // MARK: Totals

    static func total(_ entries: [WorkEntry]) -> Double {
        entries.reduce(0) { $0 + $1.hours }
    }

    static func total(_ classes: [ClassEntry]) -> Double {
        classes.reduce(0) { $0 + $1.hours }
    }

    /// Hours logged in the app plus the credit carried in at setup.
    static func totalOJT(_ entries: [WorkEntry], program: Program) -> Double {
        total(entries) + program.priorOJT
    }

    static func totalInstruction(_ classes: [ClassEntry], program: Program) -> Double {
        total(classes) + program.priorInstruction
    }

    /// Hours with no signature yet. This is what bites an apprentice the week a report is due.
    static func unsigned(_ entries: [WorkEntry]) -> [WorkEntry] {
        entries.filter { !$0.isSigned }
    }

    // MARK: Categories

    struct CategoryProgress: Identifiable, Equatable {
        let categoryID: UUID
        let name: String
        let logged: Double
        let required: Double
        var id: UUID { categoryID }

        var fraction: Double { required > 0 ? min(logged / required, 1) : 0 }
        var remaining: Double { max(0, required - logged) }
        var isComplete: Bool { required > 0 && logged >= required }
    }

    /// One row per live category, in the order the apprentice arranged them.
    static func progress(_ categories: [WorkCategory], entries: [WorkEntry]) -> [CategoryProgress] {
        categories
            .filter { !$0.archived }
            .sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
            .map { category in
                let logged = entries.filter { $0.categoryID == category.id }.reduce(0) { $0 + $1.hours } + category.priorHours
                return CategoryProgress(categoryID: category.id, name: category.displayName,
                                        logged: logged, required: category.requiredHours)
            }
    }

    /// Categories that still need hours, furthest behind first. It is the list to take to a foreman.
    static func behind(_ progress: [CategoryProgress]) -> [CategoryProgress] {
        progress.filter { $0.required > 0 && !$0.isComplete }
                .sorted { ($0.fraction, -$0.remaining) < ($1.fraction, -$1.remaining) }
    }

    /// Hours logged against categories that have since been archived or deleted, so nothing
    /// silently vanishes from the total.
    static func uncategorised(_ categories: [WorkCategory], entries: [WorkEntry]) -> Double {
        let live = Set(categories.filter { !$0.archived }.map(\.id))
        return entries.filter { !live.contains($0.categoryID) }.reduce(0) { $0 + $1.hours }
    }

    // MARK: Periods

    struct Period: Identifiable, Equatable {
        let start: Date
        let end: Date
        var id: Date { start }
    }

    /// The reporting period containing a date, aligned to the calendar year so quarters land where
    /// a sponsor expects them.
    static func period(containing date: Date, period: ReportPeriod, calendar: Calendar = .current) -> Period {
        let months = period.months
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else {
            return Period(start: date, end: date)
        }
        let index = (month - 1) / months
        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = index * months + 1
        startComponents.day = 1
        let start = calendar.date(from: startComponents) ?? date
        let end = calendar.date(byAdding: DateComponents(month: months, day: -1), to: start) ?? date
        return Period(start: start, end: calendar.startOfDay(for: end))
    }

    /// Every period from the first hours logged to today, newest first.
    static func periods(_ entries: [WorkEntry], classes: [ClassEntry], program: Program,
                        calendar: Calendar = .current, now: Date = .now) -> [Period] {
        let dates = entries.map(\.date) + classes.map(\.date)
        let earliest = dates.min() ?? program.startDate
        var current = period(containing: earliest, period: program.period, calendar: calendar)
        let last = period(containing: now, period: program.period, calendar: calendar)
        var result = [current]
        while current.start < last.start {
            guard let next = calendar.date(byAdding: .month, value: program.period.months, to: current.start) else { break }
            current = period(containing: next, period: program.period, calendar: calendar)
            result.append(current)
        }
        return result.reversed()
    }

    struct PeriodTotals: Equatable {
        var ojt: Double = 0
        var instruction: Double = 0
        var unsigned: Double = 0
        var days: Int = 0
    }

    static func totals(in period: Period, entries: [WorkEntry], classes: [ClassEntry]) -> PeriodTotals {
        let scoped = self.entries(entries, from: period.start, to: period.end)
        var totals = PeriodTotals()
        totals.ojt = total(scoped)
        totals.instruction = total(self.classes(classes, from: period.start, to: period.end))
        totals.unsigned = total(unsigned(scoped))
        totals.days = Set(scoped.map(\.day)).count
        return totals
    }

    // MARK: Pace

    /// Average OJT hours a week over the last `weeks` weeks that had any hours at all. Weeks off
    /// are excluded, because an apprentice laid off for a month is not working at half pace.
    static func weeklyPace(_ entries: [WorkEntry], weeks: Int = 12, calendar: Calendar = .current, now: Date = .now) -> Double? {
        guard let cutoff = calendar.date(byAdding: .day, value: -(weeks * 7), to: calendar.startOfDay(for: now)) else { return nil }
        let recent = entries.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return nil }
        let grouped = Dictionary(grouping: recent) { entry -> Date in
            calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.day
        }
        guard !grouped.isEmpty else { return nil }
        let weekly = grouped.values.map { $0.reduce(0) { $0 + $1.hours } }
        return weekly.reduce(0, +) / Double(weekly.count)
    }

    /// Weeks left at the recent pace. A projection from the apprentice's own hours, not a promise.
    static func weeksRemaining(_ entries: [WorkEntry], program: Program, now: Date = .now) -> Int? {
        let remaining = max(0, program.requiredOJT - totalOJT(entries, program: program))
        guard remaining > 0, let pace = weeklyPace(entries, now: now), pace > 0 else { return nil }
        return Int((remaining / pace).rounded(.up))
    }

    static func projectedFinish(_ entries: [WorkEntry], program: Program,
                                calendar: Calendar = .current, now: Date = .now) -> Date? {
        guard let weeks = weeksRemaining(entries, program: program, now: now) else { return nil }
        return calendar.date(byAdding: .day, value: weeks * 7, to: now)
    }
}
