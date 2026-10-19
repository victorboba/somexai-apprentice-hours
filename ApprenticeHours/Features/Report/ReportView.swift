import SwiftUI
import SwiftData

/// The period report: what to send, and the one place hours get marked signed.
struct ReportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Program.createdAt) private var programs: [Program]
    @Query(sort: \WorkCategory.sortIndex) private var categories: [WorkCategory]
    @Query(sort: \WorkEntry.date, order: .reverse) private var entries: [WorkEntry]
    @Query(sort: \ClassEntry.date, order: .reverse) private var classes: [ClassEntry]

    @State private var selected: Date?
    @State private var signing = false
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var editingProgram = false

    private var program: Program? { programs.first }
    private var myCategories: [WorkCategory] { categories.filter { $0.programID == program?.id } }
    private var myEntries: [WorkEntry] { entries.filter { $0.programID == program?.id } }
    private var myClasses: [ClassEntry] { classes.filter { $0.programID == program?.id } }

    private var periods: [HoursMath.Period] {
        guard let program else { return [] }
        return HoursMath.periods(myEntries, classes: myClasses, program: program)
    }
    private var period: HoursMath.Period? {
        periods.first { $0.start == selected } ?? periods.first
    }
    private var scoped: [WorkEntry] {
        guard let period else { return [] }
        return HoursMath.entries(myEntries, from: period.start, to: period.end)
    }
    private var scopedClasses: [ClassEntry] {
        guard let period else { return [] }
        return HoursMath.classes(myClasses, from: period.start, to: period.end)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let program, let period {
                    List {
                        periodSection
                        totalsSection(program, period: period)
                        signSection
                        breakdownSection
                        exportSection(program, period: period)
                        Section { Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary) }
                    }
                    .maxContentWidth()
                } else {
                    ContentUnavailableView("Nothing to report yet", systemImage: "doc.text",
                                           description: Text("Set up your programme and log a day first."))
                }
            }
            .navigationTitle("Report")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editingProgram = true } label: { Image(systemName: "person.text.rectangle") }
                        .accessibilityLabel("Programme details")
                        .disabled(program == nil)
                }
            }
            .sheet(isPresented: $editingProgram) { ProgramEditorView(program: program) }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .sheet(isPresented: $signing) {
                if let period { SignOffView(entries: HoursMath.unsigned(scoped), period: period) }
            }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    // MARK: Sections

    private var periodSection: some View {
        Section {
            Picker("Period", selection: Binding(get: { period?.start }, set: { selected = $0 })) {
                ForEach(periods) { candidate in
                    Text(label(for: candidate)).tag(Optional(candidate.start))
                }
            }
        }
    }

    private func totalsSection(_ program: Program, period: HoursMath.Period) -> some View {
        let totals = HoursMath.totals(in: period, entries: myEntries, classes: myClasses)
        let toDate = HoursMath.totalOJT(myEntries, program: program)
        return Section("This period") {
            HStack(spacing: 12) {
                StatBlock(value: Formatters.hours(totals.ojt), label: "on the job")
                StatBlock(value: "\(totals.days)", label: "days")
                StatBlock(value: Formatters.hours(totals.instruction), label: "class")
            }
            LabeledContent("Dates", value: "\(Formatters.date.string(from: period.start)) to \(Formatters.date.string(from: period.end))")
            LabeledContent("Total to date", value: "\(Formatters.hours(toDate)) of \(Formatters.hours(program.requiredOJT))")
        }
    }

    @ViewBuilder private var signSection: some View {
        let unsigned = HoursMath.unsigned(scoped)
        Section {
            if unsigned.isEmpty {
                Label(scoped.isEmpty ? "No hours in this period" : "Every hour in this period is signed",
                      systemImage: scoped.isEmpty ? "circle.dashed" : "checkmark.seal.fill")
                    .foregroundStyle(scoped.isEmpty ? Color.secondary : Color.green)
            } else {
                LabeledContent("Not yet signed", value: "\(Formatters.hours(HoursMath.total(unsigned))) · \(unsigned.count) day\(unsigned.count == 1 ? "" : "s")")
                Button {
                    signing = true
                } label: {
                    Label("Mark Signed", systemImage: "signature").fontWeight(.semibold)
                }
            }
        } header: {
            Text("Sign-off")
        } footer: {
            Text("Marking hours signed records who signed and when. It is your own record of the sign-off, not a substitute for the signature your sponsor wants on the form.")
        }
    }

    @ViewBuilder private var breakdownSection: some View {
        let grouped = Dictionary(grouping: scoped, by: \.categoryName)
            .map { (name: $0.key, hours: HoursMath.total($0.value)) }
            .sorted { $0.hours > $1.hours }
        if !grouped.isEmpty {
            Section("Hours by work process, this period") {
                ForEach(grouped, id: \.name) { row in
                    LabeledContent(row.name, value: Formatters.hours(row.hours))
                }
            }
        }
    }

    private func exportSection(_ program: Program, period: HoursMath.Period) -> some View {
        Section {
            Button {
                export {
                    try ReportExporter.export(program: program, categories: myCategories, entries: myEntries,
                                              classes: myClasses, period: period, periodLabel: label(for: period))
                }
            } label: { Label("PDF for your sponsor", systemImage: "doc.richtext") }
            Button {
                export { try CSVExporter.write(CSVExporter.entriesCSV(scoped), suffix: "hours") }
            } label: { Label("Hours CSV", systemImage: "tablecells") }
            Button {
                export { try CSVExporter.write(CSVExporter.summaryCSV(HoursMath.progress(myCategories, entries: myEntries)), suffix: "summary") }
            } label: { Label("Work process summary CSV", systemImage: "tablecells") }
            Button {
                export { try CSVExporter.write(CSVExporter.classesCSV(scopedClasses), suffix: "classes") }
            } label: { Label("Classes CSV", systemImage: "tablecells") }
        } header: {
            Text("Export")
        } footer: {
            Text("The PDF carries the period's hours, your totals to date against every required minimum, and a signature block to sign on paper.")
        }
    }

    // MARK: Helpers

    private func label(for period: HoursMath.Period) -> String {
        guard let program else { return Formatters.monthYear.string(from: period.start) }
        switch program.period {
        case .monthly:
            return Formatters.monthYear.string(from: period.start)
        case .annual:
            return String(Calendar.current.component(.year, from: period.start))
        case .quarterly, .semiannual:
            return "\(Formatters.short.string(from: period.start)) to \(Formatters.short.string(from: period.end)) \(Calendar.current.component(.year, from: period.end))"
        }
    }

    private func export(_ make: () throws -> URL) {
        do { exportFile = ExportFile(url: try make()) } catch { exportError = error.localizedDescription }
    }
}

/// Record who signed the period off and when.
struct SignOffView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let entries: [WorkEntry]
    let period: HoursMath.Period

    @AppStorage("entry.lastSupervisor") private var lastSupervisor = ""
    @State private var signedBy = ""
    @State private var signedOn = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Hours", value: Formatters.hours(HoursMath.total(entries)))
                    LabeledContent("Days", value: "\(entries.count)")
                    LabeledContent("Period", value: "\(Formatters.date.string(from: period.start)) to \(Formatters.date.string(from: period.end))")
                }
                Section {
                    TextField("Journeyman or foreman", text: $signedBy)
                    DatePicker("Signed on", selection: $signedOn, displayedComponents: .date)
                } header: {
                    Text("Who signed")
                } footer: {
                    Text("This marks every unsigned day in the period. You can undo a single day by opening it on the Hours tab.")
                }
            }
            .navigationTitle("Mark Signed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mark Signed") { sign() }
                        .fontWeight(.semibold)
                        .disabled(signedBy.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if signedBy.isEmpty { signedBy = lastSupervisor } }
        }
    }

    private func sign() {
        let name = signedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        for entry in entries {
            entry.signedAt = signedOn
            entry.signedBy = name
        }
        lastSupervisor = name
        try? context.save()
        dismiss()
    }
}
