import XCTest
import PDFKit
@testable import ApprenticeHours

final class ExportTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now))!
    }

    private func sample() -> (Program, [WorkCategory], [WorkEntry], [ClassEntry]) {
        let program = Program(apprenticeName: "Marcus Reed", trade: .electrical)
        program.apprenticeNumber = "EA-20341"
        program.sponsor = "Local 26 JATC"
        program.programNumber = "2019-NC-0114"
        program.requiredOJT = 8000
        program.requiredInstruction = 900
        program.priorOJT = 1200

        let conduit = WorkCategory(programID: program.id, name: "Conduit and raceway", requiredHours: 1000, sortIndex: 0)
        let motors = WorkCategory(programID: program.id, name: "Motors and controls", requiredHours: 600, sortIndex: 1)

        let signed = WorkEntry(programID: program.id, category: conduit, date: day(3), hours: 8)
        signed.jobSite = "Midtown Tower"
        signed.supervisor = "D. Whitaker"
        signed.signedAt = day(1)
        signed.signedBy = "D. Whitaker"

        let unsigned = WorkEntry(programID: program.id, category: motors, date: day(1), hours: 10)
        unsigned.jobSite = "Riverside Clinic"
        unsigned.supervisor = "S. Nguyen"

        let session = ClassEntry(programID: program.id, date: day(2), hours: 3, topic: "Code update, Article 250")
        session.instructor = "T. Baxter"

        return (program, [conduit, motors], [signed, unsigned], [session])
    }

    /// PDFDocument wraps text at the column width, so every phrase must be compared with whitespace collapsed.
    private func text(of url: URL) throws -> String {
        let document = try XCTUnwrap(PDFDocument(url: url))
        let raw = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: " ")
        return raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: CSV

    func testHoursCSVHasOneRowPerDayPlusTheHeader() {
        let (_, _, entries, _) = sample()
        let csv = CSVExporter.entriesCSV(entries)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(String(lines[0]), CSVExporter.entryHeader)
        XCTAssertTrue(csv.contains("\"Conduit and raceway\""))
        XCTAssertTrue(csv.contains("\"Midtown Tower\""))
    }

    func testHoursCSVRecordsWhetherEachDayIsSigned() {
        let (_, _, entries, _) = sample()
        let csv = CSVExporter.entriesCSV(entries)
        XCTAssertEqual(csv.components(separatedBy: "\"yes\"").count - 1, 1)
        XCTAssertEqual(csv.components(separatedBy: "\"no\"").count - 1, 1)
    }

    func testCSVQuotesEscapeEmbeddedQuotes() {
        let program = Program(apprenticeName: "Sam")
        let category = WorkCategory(programID: program.id, name: "Say \"hello\"", requiredHours: 10)
        let entry = WorkEntry(programID: program.id, category: category, hours: 8)
        XCTAssertTrue(CSVExporter.entriesCSV([entry]).contains("\"Say \"\"hello\"\"\""))
    }

    func testSummaryCSVLeavesRequiredBlankWhenThereIsNoMinimum() {
        let program = Program(apprenticeName: "Sam")
        let tracked = WorkCategory(programID: program.id, name: "Safety", requiredHours: 0)
        let csv = CSVExporter.summaryCSV(HoursMath.progress([tracked], entries: []))
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(String(lines[1]).hasSuffix("\"\",\"\",\"\""))
    }

    func testClassesCSVCarriesTopicAndInstructor() {
        let (_, _, _, classes) = sample()
        let csv = CSVExporter.classesCSV(classes)
        XCTAssertTrue(csv.contains("\"Code update, Article 250\""))
        XCTAssertTrue(csv.contains("\"T. Baxter\""))
    }

    // MARK: PDF

    func testPDFCarriesTheIdentityAndBothTotals() throws {
        let (program, categories, entries, classes) = sample()
        let period = HoursMath.Period(start: day(30), end: day(0))
        let url = try ReportExporter.export(program: program, categories: categories, entries: entries,
                                            classes: classes, period: period, periodLabel: "September 2026")
        let body = try text(of: url)
        XCTAssertTrue(body.contains("On-the-Job Training Report"))
        XCTAssertTrue(body.contains("Marcus Reed"))
        XCTAssertTrue(body.contains("EA-20341"))
        XCTAssertTrue(body.contains("Local 26 JATC"))
        XCTAssertTrue(body.contains("This period"))
        XCTAssertTrue(body.contains("To date"))
        try? FileManager.default.removeItem(at: url)
    }

    func testPDFListsEveryWorkProcessWithItsRequirement() throws {
        let (program, categories, entries, classes) = sample()
        let period = HoursMath.Period(start: day(30), end: day(0))
        let url = try ReportExporter.export(program: program, categories: categories, entries: entries,
                                            classes: classes, period: period, periodLabel: "September 2026")
        let body = try text(of: url)
        XCTAssertTrue(body.contains("Conduit and raceway"))
        XCTAssertTrue(body.contains("Motors and controls"))
        try? FileManager.default.removeItem(at: url)
    }

    /// The signature block is the reason the PDF exists, so it must always be on the page.
    func testPDFAlwaysCarriesASignatureBlock() throws {
        let (program, categories, entries, classes) = sample()
        let period = HoursMath.Period(start: day(30), end: day(0))
        let url = try ReportExporter.export(program: program, categories: categories, entries: entries,
                                            classes: classes, period: period, periodLabel: "September 2026")
        let body = try text(of: url)
        XCTAssertTrue(body.contains("Supervising journeyman"))
        XCTAssertTrue(body.contains("worked under my supervision"))
        try? FileManager.default.removeItem(at: url)
    }

    func testPDFSaysTheApprenticeEnteredTheRequirements() throws {
        let (program, categories, entries, classes) = sample()
        let period = HoursMath.Period(start: day(30), end: day(0))
        let url = try ReportExporter.export(program: program, categories: categories, entries: entries,
                                            classes: classes, period: period, periodLabel: "September 2026")
        XCTAssertTrue(try text(of: url).contains("You enter the hours"))
        try? FileManager.default.removeItem(at: url)
    }

    func testPDFSurvivesAnEmptyPeriod() throws {
        let program = Program(apprenticeName: "Sam")
        let period = HoursMath.Period(start: day(30), end: day(0))
        let url = try ReportExporter.export(program: program, categories: [], entries: [], classes: [],
                                            period: period, periodLabel: "September 2026")
        XCTAssertTrue(try text(of: url).contains("This period"))
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Formatting

    func testHoursReadWithASeparator() {
        XCTAssertEqual(Formatters.hours(1240), "1,240 hr")
        XCTAssertEqual(Formatters.hours(7.5), "7.5 hr")
    }

    func testMonthsUseLongUnits() {
        XCTAssertEqual(Formatters.months(7), "7 mo")
        XCTAssertEqual(Formatters.months(24), "2 yr")
        XCTAssertEqual(Formatters.months(28), "2 yr 4 mo")
    }

    func testStarterCategoriesExistForEveryTradeButOther() {
        for trade in Trade.allCases where trade != .other {
            XCTAssertFalse(trade.starterCategories.isEmpty, "\(trade.name) has no starter list")
        }
        XCTAssertTrue(Trade.other.starterCategories.isEmpty)
    }
}
