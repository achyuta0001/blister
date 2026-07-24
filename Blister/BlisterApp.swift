import SwiftUI
import SwiftData

@main
struct BlisterApp: App {
    let container = ModelContainer.blister()

    init() {
        #if DEBUG
        DebugLaunch.seedIfRequested(container)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(initialTab: RootView.Tab.fromLaunchEnvironment())
                .preferredColorScheme(.dark)
                .tint(DesignTokens.accent)
        }
        .modelContainer(container)
    }
}
