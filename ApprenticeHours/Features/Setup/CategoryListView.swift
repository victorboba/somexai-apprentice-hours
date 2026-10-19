import SwiftUI
import SwiftData

/// The work processes and their required minimums, in the order they appear on the report.
struct CategoryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Program.createdAt) private var programs: [Program]
    @Query(sort: \WorkCategory.sortIndex) private var categories: [WorkCategory]
    @Query(sort: \WorkEntry.date, order: .reverse) private var entries: [WorkEntry]

    @State private var editing: WorkCategory?
    @State private var creating = false

    private var program: Program? { programs.first }
    private var mine: [WorkCategory] {
        categories.filter { $0.programID == program?.id && !$0.archived }
                  .sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }
    private var myEntries: [WorkEntry] { entries.filter { $0.programID == program?.id } }
    private var progress: [HoursMath.CategoryProgress] { HoursMath.progress(mine, entries: myEntries) }

    var body: some View {
        Group {
            if mine.isEmpty {
                ContentUnavailableView {
                    Label("No work processes", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Add each work process your standards list, with the hours it requires.")
                } actions: {
                    Button("New Work Process") { creating = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(program == nil)
                }
            } else {
                List {
                    Section {
                        ForEach(progress) { row in
                            Button {
                                editing = mine.first { $0.id == row.categoryID }
                            } label: {
                                CategoryBar(progress: row).padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .onMove(perform: move)
                        .onDelete(perform: archive)
                    } footer: {
                        Text("Drag to reorder. Swipe to remove a process; hours already logged against it stay on your totals and on past reports.")
                    }
                }
                .maxContentWidth()
            }
        }
        .navigationTitle("Work Processes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New work process")
                    .disabled(program == nil)
            }
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        .sheet(isPresented: $creating) {
            if let program { CategoryEditorView(category: nil, program: program, nextIndex: mine.count) }
        }
        .sheet(item: $editing) { category in
            if let program { CategoryEditorView(category: category, program: program, nextIndex: category.sortIndex) }
        }
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var ordered = mine
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, category) in ordered.enumerated() { category.sortIndex = index }
        try? context.save()
    }

    /// Archived, not deleted, so hours logged against it keep their name on old reports.
    private func archive(_ offsets: IndexSet) {
        for index in offsets { mine[index].archived = true }
        try? context.save()
    }
}

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let category: WorkCategory?
    let program: Program
    let nextIndex: Int

    @State private var name = ""
    @State private var requiredText = ""
    @State private var priorText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Work process") {
                    TextField("Conduit and raceway", text: $name)
                }
                Section {
                    LabeledContent("Required") {
                        HStack {
                            TextField("0", text: $requiredText)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            Text("hr").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Already credited") {
                        HStack {
                            TextField("0", text: $priorText)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            Text("hr").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Hours")
                } footer: {
                    Text("Required comes from your own standards. Leave it at 0 to track a process without a minimum.")
                }
                if category != nil {
                    Section {
                        Button("Remove Work Process", role: .destructive) {
                            category?.archived = true
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "New Work Process" : "Work Process")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let category else { return }
                name = category.name
                requiredText = category.requiredHours > 0 ? Formatters.amount(category.requiredHours) : ""
                priorText = category.priorHours > 0 ? Formatters.amount(category.priorHours) : ""
            }
        }
    }

    private func save() {
        let target = category ?? WorkCategory(programID: program.id, sortIndex: nextIndex)
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.requiredHours = Double(requiredText) ?? 0
        target.priorHours = Double(priorText.replacingOccurrences(of: ",", with: ".")) ?? 0
        if category == nil { context.insert(target) }
        try? context.save()
        dismiss()
    }
}
