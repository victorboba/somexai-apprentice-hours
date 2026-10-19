import UIKit

/// The page an apprentice hands to the JATC or uploads to the state: the period's hours by work
/// process, the totals to date against the required minimums, and a signature block.
enum ReportExporter {
    static func export(program: Program, categories: [WorkCategory], entries: [WorkEntry],
                       classes: [ClassEntry], period: HoursMath.Period, periodLabel: String) throws -> URL {
        let scoped = HoursMath.entries(entries, from: period.start, to: period.end).sorted { $0.date < $1.date }
        let scopedClasses = HoursMath.classes(classes, from: period.start, to: period.end).sorted { $0.date < $1.date }
        let footer = "\(AppConfig.appName) · \(program.displayName)"

        return try PDFCanvas.render(footer: footer) { page in
            page.title("On-the-Job Training Report")
            page.subtitle("\(program.displayName)\(program.apprenticeNumber.isEmpty ? "" : " · \(program.apprenticeNumber)") · \(program.trade.name)")
            if !program.sponsor.isEmpty {
                page.subtitle("Sponsor: \(program.sponsor)\(program.programNumber.isEmpty ? "" : " · programme \(program.programNumber)")")
            }
            page.subtitle("Period: \(periodLabel), \(Formatters.date.string(from: period.start)) to \(Formatters.date.string(from: period.end))")
            page.subtitle("Prepared \(Formatters.dateTime.string(from: .now))")

            periodSection(page, entries: scoped, classes: scopedClasses)
            toDateSection(page, program: program, entries: entries, classes: classes)
            categorySection(page, categories: categories, entries: entries)
            entrySection(page, entries: scoped)
            classSection(page, classes: scopedClasses)
            signatureSection(page, entries: scoped)

            page.heading("About this report")
            page.paragraph(AppConfig.disclaimer, color: .darkGray)
        }
    }

    // MARK: Sections

    private static func periodSection(_ page: PDFCanvas, entries: [WorkEntry], classes: [ClassEntry]) {
        let unsigned = HoursMath.total(HoursMath.unsigned(entries))
        page.heading("This period")
        page.keyValues([
            ("On-the-job hours", Formatters.hours(HoursMath.total(entries))),
            ("Related instruction", Formatters.hours(HoursMath.total(classes))),
            ("Days worked", "\(Set(entries.map(\.day)).count)"),
            ("Hours not yet signed", unsigned > 0 ? Formatters.hours(unsigned) : "none"),
        ])
    }

    private static func toDateSection(_ page: PDFCanvas, program: Program, entries: [WorkEntry], classes: [ClassEntry]) {
        let ojt = HoursMath.totalOJT(entries, program: program)
        let instruction = HoursMath.totalInstruction(classes, program: program)
        page.heading("To date")
        page.keyValues([
            ("On-the-job hours", "\(Formatters.hours(ojt)) of \(Formatters.hours(program.requiredOJT)) · \(Formatters.percent(program.requiredOJT > 0 ? min(ojt / program.requiredOJT, 1) : 0))"),
            ("Remaining", Formatters.hours(max(0, program.requiredOJT - ojt))),
            ("Related instruction", "\(Formatters.hours(instruction)) of \(Formatters.hours(program.requiredInstruction))"),
            ("Started", Formatters.date.string(from: program.startDate)),
        ])
    }

    private static func categorySection(_ page: PDFCanvas, categories: [WorkCategory], entries: [WorkEntry]) {
        let progress = HoursMath.progress(categories, entries: entries)
        guard !progress.isEmpty else { return }
        page.heading("Hours by work process, to date")
        page.table(headers: ["Work process", "Logged", "Required", "Remaining", "Complete"],
                   widths: [0.4, 0.15, 0.15, 0.15, 0.15],
                   rows: progress.map { row in
                       [row.name,
                        Formatters.amount(row.logged),
                        row.required > 0 ? Formatters.amount(row.required) : "—",
                        row.required > 0 ? Formatters.amount(row.remaining) : "—",
                        row.required > 0 ? Formatters.percent(row.fraction) : "—"]
                   })
    }

    private static func entrySection(_ page: PDFCanvas, entries: [WorkEntry]) {
        guard !entries.isEmpty else { return }
        page.heading("Every day this period")
        page.table(headers: ["Date", "Work process", "Hours", "Job site", "Supervisor", "Signed"],
                   widths: [0.14, 0.26, 0.1, 0.2, 0.19, 0.11],
                   rows: entries.map { entry in
                       [Formatters.date.string(from: entry.date),
                        entry.categoryName,
                        Formatters.amount(entry.hours),
                        entry.jobSite,
                        entry.supervisor,
                        entry.isSigned ? "Yes" : "No"]
                   })
    }

    private static func classSection(_ page: PDFCanvas, classes: [ClassEntry]) {
        guard !classes.isEmpty else { return }
        page.heading("Related instruction this period")
        page.table(headers: ["Date", "Hours", "Topic", "Instructor"],
                   widths: [0.18, 0.12, 0.42, 0.28],
                   rows: classes.map { entry in
                       [Formatters.date.string(from: entry.date),
                        Formatters.amount(entry.hours),
                        entry.displayTopic,
                        entry.instructor]
                   })
    }

    /// A block to sign on paper, because that is still how most sponsors accept the hours.
    private static func signatureSection(_ page: PDFCanvas, entries: [WorkEntry]) {
        page.heading("Signatures")
        page.paragraph("I certify that the hours recorded above were worked under my supervision.")
        page.spacer(18)
        page.keyValues([
            ("Supervising journeyman", "______________________________________      Date: ______________"),
            ("Apprentice", "______________________________________      Date: ______________"),
        ])
        let signed = entries.filter(\.isSigned)
        if !signed.isEmpty {
            page.spacer(6)
            let names = Set(signed.map(\.signedBy)).filter { !$0.isEmpty }.sorted()
            page.paragraph("Already marked signed in the app: \(Formatters.hours(HoursMath.total(signed)))"
                           + (names.isEmpty ? "." : " by \(names.joined(separator: ", "))."),
                           color: .darkGray)
        }
    }
}
