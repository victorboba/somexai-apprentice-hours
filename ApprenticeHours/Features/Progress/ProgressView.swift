import SwiftUI
import SwiftData

/// Home: the ring, this period, what is unsigned, and the work processes you are short on.
struct HoursProgressView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Program.createdAt) private var programs: [Program]
    @Query(sort: \WorkCategory.sortIndex) private var categories: [WorkCategory]
    @Query(sort: \WorkEntry.date, order: .reverse) private var entries: [WorkEntry]
    @Query(sort: \ClassEntry.date, order: .reverse) private var classes: [ClassEntry]

    @State private var editingProgram = false
    @State private var showingSettings = false

    private var program: Program? { programs.first }
    private var myCategories: [WorkCategory] { categories.filter { $0.programID == program?.id } }
    private var myEntries: [WorkEntry] { entries.filter { $0.programID == program?.id } }
    private var myClasses: [ClassEntry] { classes.filter { $0.programID == program?.id } }
    private var progress: [HoursMath.CategoryProgress] { HoursMath.progress(myCategories, entries: myEntries) }

    private var currentPeriod: HoursMath.Period? {
        guard let program else { return nil }
        return HoursMath.period(containing: .now, period: program.period)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let program {
                    VStack(spacing: 14) {
                        ringCard(program)
                        periodCard(program)
                        unsignedCard
                        behindCard
                        instructionCard(program)
                        Text(AppConfig.disclaimer)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .maxContentWidth()
                } else {
                    ContentUnavailableView {
                        Label("Set up your programme", systemImage: "person.text.rectangle")
                    } description: {
                        Text("Your trade, the hours your standards require, and the work processes you have to cover.")
                    } actions: {
                        Button("Set Up") { editingProgram = true }.buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 60)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(program.map { "\($0.displayName), \($0.trade.name.lowercased())" } ?? "Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                    NavigationLink { HowToView() } label: { Image(systemName: "questionmark.circle") }
                        .accessibilityLabel("How do I use this app")
                }
            }
            .sheet(isPresented: $editingProgram) { ProgramEditorView(program: program) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sampleData"), programs.isEmpty {
                SampleData.insert(into: context)
            }
            #endif
        }
        .onChange(of: entries.count, initial: true) { sync() }
        .onChange(of: classes.count) { sync() }
        .onChange(of: programs.count) { sync() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            WidgetSnapshot.defaults.removeObject(forKey: LogHoursIntent.pendingKey)
        }
    }

    // MARK: Cards

    private func ringCard(_ program: Program) -> some View {
        let logged = HoursMath.totalOJT(myEntries, program: program)
        return Panel {
            HStack(spacing: 18) {
                HoursRing(logged: logged, required: program.requiredOJT)
                VStack(alignment: .leading, spacing: 10) {
                    StatBlock(value: Formatters.hours(logged), label: "on the job")
                    StatBlock(value: Formatters.hours(max(0, program.requiredOJT - logged)), label: "to go")
                    if let weeks = HoursMath.weeksRemaining(myEntries, program: program) {
                        StatBlock(value: weeks < 8 ? "\(weeks) weeks" : Formatters.months(weeks / 4),
                                  label: "at your recent pace")
                    }
                }
            }
        }
    }

    @ViewBuilder private func periodCard(_ program: Program) -> some View {
        if let period = currentPeriod {
            let totals = HoursMath.totals(in: period, entries: myEntries, classes: myClasses)
            Panel(title: "\(program.period.currentLabel) so far") {
                HStack(spacing: 16) {
                    StatBlock(value: Formatters.hours(totals.ojt), label: "on the job")
                    StatBlock(value: "\(totals.days)", label: "days worked")
                    StatBlock(value: Formatters.hours(totals.instruction), label: "class")
                }
                Text("\(Formatters.date.string(from: period.start)) to \(Formatters.date.string(from: period.end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var unsignedCard: some View {
        let unsigned = HoursMath.unsigned(myEntries)
        if !unsigned.isEmpty {
            Panel {
                Label("\(Formatters.hours(HoursMath.total(unsigned))) not signed", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("\(unsigned.count) day\(unsigned.count == 1 ? "" : "s") across \(Set(unsigned.map { Calendar.current.component(.month, from: $0.date) }).count) month\(Set(unsigned.map { Calendar.current.component(.month, from: $0.date) }).count == 1 ? "" : "s"). Mark them signed on the Report tab when your journeyman signs off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var behindCard: some View {
        let behind = HoursMath.behind(progress)
        if !behind.isEmpty {
            Panel(title: "Furthest behind") {
                VStack(spacing: 14) {
                    ForEach(behind.prefix(4)) { row in
                        CategoryBar(progress: row)
                    }
                }
                NavigationLink {
                    CategoryListView()
                } label: {
                    Text("All \(progress.count) work processes").font(.subheadline.weight(.semibold))
                }
            }
        } else if !progress.isEmpty {
            Panel(title: "Work processes") {
                Label("Every required minimum is met.", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                NavigationLink {
                    CategoryListView()
                } label: {
                    Text("All \(progress.count) work processes").font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private func instructionCard(_ program: Program) -> some View {
        let logged = HoursMath.totalInstruction(myClasses, program: program)
        return Panel(title: "Related instruction") {
            CategoryBar(progress: .init(categoryID: program.id, name: "Classroom hours",
                                        logged: logged, required: program.requiredInstruction))
        }
    }

    private func sync() {
        guard let program else {
            WidgetSync.update(program: nil, categories: [], entries: [], classes: [])
            return
        }
        WidgetSync.update(program: program, categories: myCategories, entries: myEntries, classes: myClasses)
    }
}
