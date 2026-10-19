import SwiftUI
import SwiftData

/// The programme: who you are, what your standards require, and what you were credited before
/// you installed this. Every figure is the apprentice's own.
struct ProgramEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let program: Program?

    @State private var apprenticeName = ""
    @State private var apprenticeNumber = ""
    @State private var trade: Trade = .electrical
    @State private var sponsor = ""
    @State private var programNumber = ""
    @State private var startDate = Date.now
    @State private var requiredOJTText = "8000"
    @State private var requiredInstructionText = "900"
    @State private var priorOJTText = ""
    @State private var priorInstructionText = ""
    @State private var period: ReportPeriod = .monthly

    private var requiredOJT: Double { Double(requiredOJTText) ?? 0 }
    private var requiredInstruction: Double { Double(requiredInstructionText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Your name", text: $apprenticeName)
                    TextField("Apprentice number", text: $apprenticeNumber)
                    Picker("Trade", selection: $trade) {
                        ForEach(Trade.allCases) { Label($0.name, systemImage: $0.symbol).tag($0) }
                    }
                }

                Section {
                    TextField("JATC, employer or committee", text: $sponsor)
                    TextField("Programme number", text: $programNumber)
                    DatePicker("Started", selection: $startDate, displayedComponents: .date)
                    Picker("Report every", selection: $period) {
                        ForEach(ReportPeriod.allCases) { Text($0.name).tag($0) }
                    }
                } header: {
                    Text("Your programme")
                } footer: {
                    Text("The sponsor and programme number print at the top of the report. The period sets how the Report tab groups your hours.")
                }

                Section {
                    LabeledContent("On the job") {
                        HStack {
                            TextField("8000", text: $requiredOJTText)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            Text("hr").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Related instruction") {
                        HStack {
                            TextField("900", text: $requiredInstructionText)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            Text("hr").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Hours your standards require")
                } footer: {
                    Text("Copy these from your own standards of apprenticeship. They differ by state, trade and sponsor, and the app does not know yours.")
                }

                Section {
                    LabeledContent("On the job") {
                        HStack {
                            TextField("0", text: $priorOJTText)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            Text("hr").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Related instruction") {
                        HStack {
                            TextField("0", text: $priorInstructionText)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            Text("hr").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Hours already credited")
                } footer: {
                    Text("What your sponsor has on file for you today. These are added to your totals so you do not start from zero.")
                }

                Section {
                    Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(program == nil ? "Set Up" : "Programme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(apprenticeName.trimmingCharacters(in: .whitespaces).isEmpty || requiredOJT <= 0)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let program else { return }
        apprenticeName = program.apprenticeName
        apprenticeNumber = program.apprenticeNumber
        trade = program.trade
        sponsor = program.sponsor
        programNumber = program.programNumber
        startDate = program.startDate
        requiredOJTText = Formatters.amount(program.requiredOJT)
        requiredInstructionText = Formatters.amount(program.requiredInstruction)
        priorOJTText = program.priorOJT > 0 ? Formatters.amount(program.priorOJT) : ""
        priorInstructionText = program.priorInstruction > 0 ? Formatters.amount(program.priorInstruction) : ""
        period = program.period
    }

    private func save() {
        let isNew = program == nil
        let target = program ?? Program()
        target.apprenticeName = apprenticeName.trimmingCharacters(in: .whitespacesAndNewlines)
        target.apprenticeNumber = apprenticeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        target.trade = trade
        target.sponsor = sponsor.trimmingCharacters(in: .whitespacesAndNewlines)
        target.programNumber = programNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        target.startDate = startDate
        target.requiredOJT = requiredOJT
        target.requiredInstruction = requiredInstruction
        target.priorOJT = Double(priorOJTText.replacingOccurrences(of: ",", with: ".")) ?? 0
        target.priorInstruction = Double(priorInstructionText.replacingOccurrences(of: ",", with: ".")) ?? 0
        target.period = period
        if isNew {
            context.insert(target)
            // Give the apprentice something to edit rather than a blank list.
            for (index, starter) in trade.starterCategories.enumerated() {
                context.insert(WorkCategory(programID: target.id, name: starter.0,
                                            requiredHours: starter.1, sortIndex: index))
            }
        }
        try? context.save()
        dismiss()
    }
}
