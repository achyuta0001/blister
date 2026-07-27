import SwiftUI

/// Top-level tab shell. Aisle Check sits first in the tab bar — it is the one moment the app exists
/// for and must be reachable in one tap from anywhere (spec §6.1) — but the app *opens* on Garage,
/// the screen people return to between store trips. Tab order and startup tab are independent; keep
/// the order as-is. Each tab body is owned by one feature agent, so agents fill in their view rather
/// than restructure this shell.
struct RootView: View {
    enum Tab: String, Hashable {
        case aisle, garage, wishlist, settings

        /// Reads the starting tab from `BLISTER_START_TAB` (debug launch aid); defaults to Garage.
        static func fromLaunchEnvironment() -> Tab {
            #if DEBUG
            if let raw = ProcessInfo.processInfo.environment["BLISTER_START_TAB"],
               let tab = Tab(rawValue: raw) {
                return tab
            }
            #endif
            return .garage
        }
    }

    @State private var selection: Tab

    #if DEBUG
    @Environment(\.modelContext) private var modelContext
    @State private var debugStudioPhoto: DebugStudioPhoto?

    /// Identifiable wrapper so a `UIImage` can drive `.fullScreenCover(item:)`.
    private struct DebugStudioPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
    }
    #endif

    init(initialTab: Tab = .garage) {
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            SwiftUI.Tab(String(localized: "Aisle"), systemImage: "magnifyingglass", value: Tab.aisle) {
                AisleCheckView()
            }
            SwiftUI.Tab(String(localized: "Garage"), systemImage: "square.grid.2x2", value: Tab.garage) {
                GarageView()
            }
            SwiftUI.Tab(String(localized: "Wishlist"), systemImage: "star", value: Tab.wishlist) {
                WishlistView()
            }
            SwiftUI.Tab(String(localized: "Settings"), systemImage: "gearshape", value: Tab.settings) {
                SettingsView()
            }
        }
        .tint(DesignTokens.accent)
    }
}

#Preview {
    RootView()
        .modelContainer(.inMemory(seeded: true))
        .preferredColorScheme(.dark)
}
