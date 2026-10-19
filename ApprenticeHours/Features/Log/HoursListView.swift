import SwiftUI
import SwiftData

/// Every day logged, newest first, grouped by week with the week's total in the header.
struct HoursListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Program.createdAt) private var programs: [Program]
    @Query(sort: \WorkCategory.sortIndex) private var categories: [WorkCategory]
    @Query(sort: \WorkEntry.date, order: .reverse) private var entries: [WorkEntry]

    @State private var adding = false
    @State private var editing: WorkEntry?

    private var program: Program? { programs.first }
    private var myCategories: [WorkCategory] { categories.filter { $0.programID == program?.id && !$0.archived } }
    private var mine: [WorkEntry] { entries.filter { $0.programID == program?.id } }

    private var weeks: [(start: Date, entries: [WorkEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: mine) { entry in
            calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start ?? entry.day
        }
        return grouped.keys.sorted(by: >).map { (start: $0, entries: (grouped[$0] ?? []).sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if program == nil {
                    ContentUnavailableView("No programme yet", systemImage: "hammer",
                                           description: Text("Set up your programme on the Progress tab first."))
                } else if myCategories.isEmpty {
                    ContentUnavailableView {
                        Label("No work processes", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Add the work processes your standards list before you log hours against them.")
                    } actions: {
                        NavigationLink("Add Work Processes") { CategoryListView() }.buttonStyle(.borderedProminent)
                    }
                } else if mine.isEmpty {
                    ContentUnavailableView {
                        Label("No hours yet", systemImage: "clock")
                    } description: {
                        Text("Log the day's hours against the work process you spent them on.")
                    } actions: {
                        Button("Log Hours") { adding = true }.buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(weeks, id: \.start) { week in
                            Section {
                                ForEach(week.entries) { entry in
                                    Button { editing = entry } label: { EntryRow(entry: entry) }
                                        .buttonStyle(.plain)
                                }
                                .onDelete { offsets in delete(offsets.map { week.entries[$0] }) }
                            } header: {
                                HStack {
                                    Text("Week of \(Formatters.short.string(from: week.start))")
                                    Spacer()
                                    Text(Formatters.hours(HoursMath.total(week.entries))).monospacedDigit()
                                }
                            }
                        }
                    }
                    .maxContentWidth()
                }
            }
            .navigationTitle("Hours")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Log hours")
                        .disabled(program == nil || myCategories.isEmpty)
                }
            }
            .sheet(isPresented: $adding) {
                if let program { EntryEditorView(program: program, entry: nil) }
            }
            .sheet(item: $editing) { entry in
                if let program { EntryEditorView(program: program, entry: entry) }
            }
        }
    }

    private func delete(_ toDelete: [WorkEntry]) {
        for entry in toDelete { context.delete(entry) }
    }
}

/// Log or change one day. The work process defaults to the last one used, because most weeks
/// are several days on the same thing.
struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \WorkCategory.sortIndex) private var categories: [WorkCategory]
    @Query(sort: \WorkEntry.date, order: .reverse) private var allEntries: [WorkEntry]

    let program: Program
    let entry: WorkEntry?

    @AppStorage("entry.lastCategory") private var lastCategoryID = ""
    @AppStorage("entry.lastJobSite") private var lastJobSite = ""
    @AppStorage("entry.lastSupervisor") private var lastSupervisor = ""

    @State private var date = Date.now
    @State private var categoryID: UUID?
    @State private var hoursText = "8"
    @State private var jobSite = ""
    @State private var supervisor = ""
    @State private var notes = ""
    @FocusState private var hoursFocused: Bool

    private var myCategories: [WorkCategory] {
        categories.filter { $0.programID == program.id && !$0.archived }
                  .sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }
    private var hours: Double? { Double(hoursText.replacingOccurrences(of: ",", with: ".")) }
    private var canSave: Bool { categoryID != nil && (hours ?? 0) > 0 }

    /// The processes used most recently, so the common case is one tap.
    private var recent: [WorkCategory] {
        let used = allEntries.filter { $0.programID == program.id }.prefix(40).map(\.categoryID)
        var seen: [UUID] = []
        for id in used where !seen.contains(id) { seen.append(id) }
        return seen.compactMap { id in myCategories.first { $0.id == id } }.prefix(4).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Hours")
                        Spacer()
                        TextField("8", text: $hoursText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .focused($hoursFocused)
                            .frame(width: 90)
                    }
                    quickHours
                }

                Section("Work process") {
                    if !recent.isEmpty && entry == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recent) { category in
                                    Button(category.displayName) { categoryID = category.id }
                                        .font(.caption.weight(.semibold))
                                        .buttonStyle(.bordered)
                                        .buttonBorderShape(.capsule)
                                        .tint(categoryID == category.id ? .accentColor : .secondary)
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }
                    Picker("Work process", selection: $categoryID) {
                        Text("Choose").tag(UUID?.none)
                        ForEach(myCategories) { Text($0.displayName).tag(UUID?.some($0.id)) }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                }

                Section("Where and who") {
                    TextField("Job site", text: $jobSite)
                    TextField("Supervising journeyman", text: $supervisor)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(1...4)
                }

                if let entry, entry.isSigned {
                    Section {
                        LabeledContent("Signed", value: entry.signedBy.isEmpty ? "yes" : entry.signedBy)
                        Button("Mark not signed", role: .destructive) {
                            entry.signedAt = nil
                            entry.signedBy = ""
                        }
                    }
                }

                if entry != nil {
                    Section {
                        Button("Delete Entry", role: .destructive) {
                            if let entry { context.delete(entry) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Log Hours" : "Edit Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.fontWeight(.semibold).disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hoursFocused = false }
                }
            }
            .onAppear(perform: load)
        }
    }

    private var quickHours: some View {
        HStack(spacing: 8) {
            ForEach([4.0, 6.0, 8.0, 10.0, 12.0], id: \.self) { value in
                Button(Formatters.amount(value)) { hoursText = Formatters.amount(value) }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(hours == value ? .accentColor : .secondary)
            }
        }
        .accessibilityLabel("Common hours")
    }

    private func load() {
        guard let entry else {
            categoryID = UUID(uuidString: lastCategoryID).flatMap { id in myCategories.first { $0.id == id }?.id }
                ?? myCategories.first?.id
            jobSite = lastJobSite
            supervisor = lastSupervisor
            return
        }
        date = entry.date
        categoryID = entry.categoryID
        hoursText = Formatters.amount(entry.hours)
        jobSite = entry.jobSite
        supervisor = entry.supervisor
        notes = entry.notes
    }

    private func save() {
        guard let hours, let categoryID, let category = myCategories.first(where: { $0.id == categoryID }) else { return }
        let target: WorkEntry
        if let entry {
            target = entry
            target.categoryID = category.id
            target.categoryName = category.displayName
        } else {
            target = WorkEntry(programID: program.id, category: category)
            context.insert(target)
        }
        target.date = date
        target.hours = hours
        target.jobSite = jobSite.trimmingCharacters(in: .whitespacesAndNewlines)
        target.supervisor = supervisor.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        lastCategoryID = category.id.uuidString
        lastJobSite = target.jobSite
        lastSupervisor = target.supervisor
        try? context.save()
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}
