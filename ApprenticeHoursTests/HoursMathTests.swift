import XCTest
@testable import ApprenticeHours

final class HoursMathTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func makeProgram(required: Double = 8000, period: ReportPeriod = .monthly,
                             priorOJT: Double = 0, priorInstruction: Double = 0) -> Program {
        let program = Program(apprenticeName: "Marcus", trade: .electrical)
        program.requiredOJT = required
        program.requiredInstruction = 900
        program.priorOJT = priorOJT
        program.priorInstruction = priorInstruction
        program.period = period
        return program
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func category(_ name: String = "Conduit", required: Double = 1000,
                          prior: Double = 0, programID: UUID, index: Int = 0) -> WorkCategory {
        let c = WorkCategory(programID: programID, name: name, requiredHours: required, sortIndex: index)
        c.priorHours = prior
        return c
    }

    private func entry(_ category: WorkCategory, hours: Double, offset: Int = 0,
                       programID: UUID, signed: Bool = false) -> WorkEntry {
        let e = WorkEntry(programID: programID, category: category, date: day(offset), hours: hours)
        if signed { e.signedAt = day(offset); e.signedBy = "D. Whitaker" }
        return e
    }

    // MARK: Totals

    func testTotalAddsEveryEntry() {
        let program = makeProgram()
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 8, programID: program.id),
                       entry(conduit, hours: 6.5, offset: 1, programID: program.id)]
        XCTAssertEqual(HoursMath.total(entries), 14.5, accuracy: 0.0001)
    }

    /// Credited hours from before the app was installed must be in the total, or the ring is wrong
    /// for a third-year apprentice on day one.
    func testPriorCreditCountsTowardTheTotal() {
        let program = makeProgram(priorOJT: 3200)
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 40, programID: program.id)]
        XCTAssertEqual(HoursMath.totalOJT(entries, program: program), 3240)
    }

    func testPriorInstructionCountsToo() {
        let program = makeProgram(priorInstruction: 300)
        let classes = [ClassEntry(programID: program.id, hours: 3, topic: "Code update")]
        XCTAssertEqual(HoursMath.totalInstruction(classes, program: program), 303)
    }

    func testUnsignedPicksOutOnlyUnsignedDays() {
        let program = makeProgram()
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 8, programID: program.id, signed: true),
                       entry(conduit, hours: 8, offset: 1, programID: program.id)]
        XCTAssertEqual(HoursMath.unsigned(entries).count, 1)
        XCTAssertEqual(HoursMath.total(HoursMath.unsigned(entries)), 8)
    }

    func testEntriesAreFilteredByProgramme() {
        let mine = makeProgram()
        let theirs = makeProgram()
        let conduit = category(programID: mine.id)
        let entries = [entry(conduit, hours: 8, programID: mine.id),
                       entry(conduit, hours: 8, programID: theirs.id)]
        XCTAssertEqual(HoursMath.entries(entries, in: mine.id).count, 1)
    }

    func testDateRangeIncludesBothEndDays() {
        let program = makeProgram()
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 8, offset: 0, programID: program.id),
                       entry(conduit, hours: 8, offset: 3, programID: program.id),
                       entry(conduit, hours: 8, offset: 9, programID: program.id)]
        XCTAssertEqual(HoursMath.entries(entries, from: day(3), to: day(0)).count, 2)
    }

    // MARK: Categories

    func testProgressCountsHoursAndPriorCreditPerCategory() {
        let program = makeProgram()
        let conduit = category("Conduit", required: 1000, prior: 200, programID: program.id, index: 0)
        let wire = category("Wire", required: 1000, programID: program.id, index: 1)
        let entries = [entry(conduit, hours: 8, programID: program.id),
                       entry(wire, hours: 16, programID: program.id)]
        let progress = HoursMath.progress([conduit, wire], entries: entries)
        XCTAssertEqual(progress.map(\.name), ["Conduit", "Wire"])
        XCTAssertEqual(progress[0].logged, 208)
        XCTAssertEqual(progress[1].logged, 16)
    }

    func testProgressFractionCapsAtOneWhenOver() {
        let program = makeProgram()
        let conduit = category("Conduit", required: 100, programID: program.id)
        let entries = [entry(conduit, hours: 150, programID: program.id)]
        let row = HoursMath.progress([conduit], entries: entries)[0]
        XCTAssertEqual(row.fraction, 1)
        XCTAssertEqual(row.remaining, 0)
        XCTAssertTrue(row.isComplete)
    }

    func testArchivedCategoriesDropOutOfProgress() {
        let program = makeProgram()
        let live = category("Conduit", programID: program.id, index: 0)
        let gone = category("Wire", programID: program.id, index: 1)
        gone.archived = true
        XCTAssertEqual(HoursMath.progress([live, gone], entries: []).count, 1)
    }

    /// Hours logged against a removed process must still be visible somewhere, not silently lost.
    func testHoursOnArchivedCategoriesAreReportedSeparately() {
        let program = makeProgram()
        let live = category("Conduit", programID: program.id, index: 0)
        let gone = category("Wire", programID: program.id, index: 1)
        gone.archived = true
        let entries = [entry(live, hours: 8, programID: program.id),
                       entry(gone, hours: 12, programID: program.id)]
        XCTAssertEqual(HoursMath.uncategorised([live, gone], entries: entries), 12)
    }

    func testBehindRanksTheFurthestBehindFirstAndSkipsCompleteOnes() {
        let program = makeProgram()
        let nearlyDone = category("Conduit", required: 100, programID: program.id, index: 0)
        let barelyStarted = category("Motors", required: 600, programID: program.id, index: 1)
        let done = category("Lighting", required: 50, programID: program.id, index: 2)
        let entries = [entry(nearlyDone, hours: 90, programID: program.id),
                       entry(barelyStarted, hours: 30, programID: program.id),
                       entry(done, hours: 50, programID: program.id)]
        let behind = HoursMath.behind(HoursMath.progress([nearlyDone, barelyStarted, done], entries: entries))
        XCTAssertEqual(behind.map(\.name), ["Motors", "Conduit"])
    }

    func testCategoriesWithNoMinimumAreNeverBehind() {
        let program = makeProgram()
        let tracked = category("Safety", required: 0, programID: program.id)
        XCTAssertTrue(HoursMath.behind(HoursMath.progress([tracked], entries: [])).isEmpty)
    }

    // MARK: Periods

    func testMonthlyPeriodIsTheCalendarMonth() {
        let period = HoursMath.period(containing: date(2026, 9, 17), period: .monthly, calendar: calendar)
        XCTAssertEqual(period.start, date(2026, 9, 1))
        XCTAssertEqual(period.end, date(2026, 9, 30))
    }

    /// Quarters have to land where a sponsor expects them, not three months back from today.
    func testQuarterlyPeriodsAlignToTheCalendarYear() {
        let q3 = HoursMath.period(containing: date(2026, 8, 14), period: .quarterly, calendar: calendar)
        XCTAssertEqual(q3.start, date(2026, 7, 1))
        XCTAssertEqual(q3.end, date(2026, 9, 30))
        let q1 = HoursMath.period(containing: date(2026, 1, 2), period: .quarterly, calendar: calendar)
        XCTAssertEqual(q1.start, date(2026, 1, 1))
        XCTAssertEqual(q1.end, date(2026, 3, 31))
    }

    func testAnnualPeriodIsTheWholeYear() {
        let period = HoursMath.period(containing: date(2026, 6, 9), period: .annual, calendar: calendar)
        XCTAssertEqual(period.start, date(2026, 1, 1))
        XCTAssertEqual(period.end, date(2026, 12, 31))
    }

    func testSemiannualSplitsTheYearInHalf() {
        let second = HoursMath.period(containing: date(2026, 11, 3), period: .semiannual, calendar: calendar)
        XCTAssertEqual(second.start, date(2026, 7, 1))
        XCTAssertEqual(second.end, date(2026, 12, 31))
    }

    func testPeriodsRunNewestFirstAndCoverEveryMonthWithHours() {
        let program = makeProgram(period: .monthly)
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 8, offset: 0, programID: program.id),
                       entry(conduit, hours: 8, offset: 70, programID: program.id)]
        let periods = HoursMath.periods(entries, classes: [], program: program, calendar: calendar)
        XCTAssertGreaterThanOrEqual(periods.count, 3)
        XCTAssertTrue(periods[0].start > periods[1].start)
    }

    func testPeriodTotalsSplitOJTFromInstructionAndCountDaysOnce() {
        let program = makeProgram()
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 8, offset: 0, programID: program.id),
                       entry(conduit, hours: 2, offset: 0, programID: program.id),
                       entry(conduit, hours: 8, offset: 1, programID: program.id)]
        let classes = [ClassEntry(programID: program.id, date: day(1), hours: 3, topic: "Code")]
        let period = HoursMath.Period(start: day(5), end: day(0))
        let totals = HoursMath.totals(in: period, entries: entries, classes: classes)
        XCTAssertEqual(totals.ojt, 18)
        XCTAssertEqual(totals.instruction, 3)
        XCTAssertEqual(totals.days, 2)
        XCTAssertEqual(totals.unsigned, 18)
    }

    // MARK: Pace

    func testWeeklyPaceAveragesOverWeeksThatHadHours() {
        let program = makeProgram()
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 40, offset: 2, programID: program.id),
                       entry(conduit, hours: 20, offset: 9, programID: program.id)]
        let pace = HoursMath.weeklyPace(entries, weeks: 12, calendar: calendar)
        XCTAssertNotNil(pace)
        XCTAssertEqual(pace ?? 0, 30, accuracy: 0.0001)
    }

    func testWeeklyPaceIsNilWithNoRecentHours() {
        let program = makeProgram()
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 40, offset: 400, programID: program.id)]
        XCTAssertNil(HoursMath.weeklyPace(entries, weeks: 12, calendar: calendar))
    }

    func testWeeksRemainingDividesWhatIsLeftByThePace() {
        let program = makeProgram(required: 200, priorOJT: 100)
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 20, offset: 2, programID: program.id)]
        XCTAssertEqual(HoursMath.weeksRemaining(entries, program: program), 4)
    }

    func testWeeksRemainingIsNilOnceTheHoursAreDone() {
        let program = makeProgram(required: 100, priorOJT: 100)
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 20, offset: 2, programID: program.id)]
        XCTAssertNil(HoursMath.weeksRemaining(entries, program: program))
    }

    func testProjectedFinishIsInTheFuture() {
        let program = makeProgram(required: 300, priorOJT: 100)
        let conduit = category(programID: program.id)
        let entries = [entry(conduit, hours: 20, offset: 2, programID: program.id)]
        let finish = HoursMath.projectedFinish(entries, program: program, calendar: calendar)
        XCTAssertNotNil(finish)
        XCTAssertGreaterThan(finish ?? .distantPast, Date.now)
    }
}
