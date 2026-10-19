import SwiftUI
import SwiftData

/// Related instruction: night school, upgrade classes, online modules. Sponsors count these
/// separately from on-the-job hours, so the app does too.
struct ClassListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Program.createdAt) private var programs: [Program]
    @Query(sort: \ClassEntry.date, order: .reverse) private var classes: [ClassEntry]

    @State private var adding = false
    @State private var editing: ClassEntry?

    private var program: Program? { programs.first }
    private var mine: [ClassEntry] { classes.filter { $0.programID == program?.id } }

    private var months: [(start: Date, entries: [ClassEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: mine) { entry in
            calendar.date(from: calendar.dateComponents([.year, .month], from: entry.date)) ?? entry.day
        }
        return grouped.keys.sorted(by: >).map { (start: $0, entries: (grouped[$0] ?? []).sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let program {
                    if mine.isEmpty {
                        ContentUnavailableView {
                            Label("No class hours", systemImage: "book")
                        } description: {
                            Text("Log each session of related instruction. Your sponsor counts these apart from your on-the-job hours.")
                        } actions: {
                            Button("Log a Class") { adding = true }.buttonStyle(.borderedProminent)
                        }
                    } else {
                        List {
                            Section {
                                CategoryBar(progress: .init(categoryID: program.id, name: "Classroom hours",
                                                            logged: HoursMath.totalInstruction(mine, program: program),
                                                            required: program.requiredInstruction))
                                .padding(.vertical, 4)
                            }
                            ForEach(months, id: \.start) { month in
                                Section {
                                    ForEach(month.entries) { entry in
                                        Button { editing = entry } label: { ClassRow(entry: entry) }
                                            .buttonStyle(.plain)
                                    }
                                    .onDelete { offsets in delete(offsets.map { month.entries[$0] }) }
                                } header: {
                                    HStack {
                                        Text(Formatters.monthYear.string(from: month.start))
                                        Spacer()
                                        Text(Formatters.hours(HoursMath.total(month.entries))).monospacedDigit()
                                    }
                                }
                            }
                        }
                        .maxContentWidth()
                    }
                } else {
                    ContentUnavailableView("No programme yet", systemImage: "book",
                                           description: Text("Set up your programme on the Progress tab first."))
                }
            }
            .navigationTitle("Classes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Log a class")
                        .disabled(program == nil)
                }
            }
            .sheet(isPresented: $adding) {
                if let program { ClassEditorView(program: program, entry: nil) }
            }
            .sheet(item: $editing) { entry in
                if let program { ClassEditorView(program: program, entry: entry) }
            }
        }
    }

    private func delete(_ toDelete: [ClassEntry]) {
        for entry in toDelete { context.delete(entry) }
    }
}

struct ClassEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let program: Program
    let entry: ClassEntry?

    @AppStorage("class.lastInstructor") private var lastInstructor = ""

    @State private var date = Date.now
    @State private var hoursText = "3"
    @State private var topic = ""
    @State private var instructor = ""
    @State private var notes = ""
    @FocusState private var hoursFocused: Bool

    private var hours: Double? { Double(hoursText.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Hours")
                        Spacer()
                        TextField("3", text: $hoursText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .focused($hoursFocused)
                            .frame(width: 90)
                    }
                }
                Section("What it covered") {
                    TextField("Conduit bending, code update, OSHA 30…", text: $topic)
                    TextField("Instructor or school", text: $instructor)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(1...4)
                }
                if entry != nil {
                    Section {
                        Button("Delete Class", role: .destructive) {
                            if let entry { context.delete(entry) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Log a Class" : "Edit Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled((hours ?? 0) <= 0)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hoursFocused = false }
                }
            }
            .onAppear {
                guard let entry else {
                    instructor = lastInstructor
                    return
                }
                date = entry.date
                hoursText = Formatters.amount(entry.hours)
                topic = entry.topic
                instructor = entry.instructor
                notes = entry.notes
            }
        }
    }

    private func save() {
        guard let hours else { return }
        let target = entry ?? ClassEntry(programID: program.id)
        target.date = date
        target.hours = hours
        target.topic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        target.instructor = instructor.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry == nil { context.insert(target) }
        lastInstructor = target.instructor
        try? context.save()
        dismiss()
    }
}
