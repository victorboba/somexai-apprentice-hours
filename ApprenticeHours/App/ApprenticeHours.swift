import SwiftUI
import SwiftData

@main
struct ApprenticeHours: App {
    @State private var entitlements = EntitlementStore()
    private let container: ModelContainer

    init() {
        let schema = Schema([Program.self, WorkCategory.self, WorkEntry.self, ClassEntry.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: AppConfig.iCloudSyncEnabled ? .automatic : .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the SwiftData container: \(error)")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            try? container.mainContext.delete(model: WorkEntry.self)
            try? container.mainContext.delete(model: ClassEntry.self)
            try? container.mainContext.delete(model: WorkCategory.self)
            try? container.mainContext.delete(model: Program.self)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
        }
        .modelContainer(container)
    }
}
