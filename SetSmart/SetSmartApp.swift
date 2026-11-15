import SwiftUI
import SwiftData

@main
struct SetSmartApp: App {
    @State private var appState = AppState()

    // SwiftData container kept for future local caching
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return (try? ModelContainer(for: schema, configurations: [config]))
            ?? (try! ModelContainer(for: schema))
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
