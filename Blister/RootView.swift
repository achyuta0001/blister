import SwiftUI

/// Top-level tab shell. Aisle Check is first — it is the one moment the app exists for and must be
/// reachable in one tap from anywhere (spec §6.1). Each tab body is owned by one feature agent;
/// this file is a frozen contract, so agents fill in their view rather than edit this shell.
struct RootView: View {
    enum Tab: String, Hashable {
        case aisle, garage, wishlist, settings

        /// Reads the starting tab from `BLISTER_START_TAB` (debug launch aid); defaults to Aisle.
        static func fromLaunchEnvironment() -> Tab {
            #if DEBUG
            if let raw = ProcessInfo.processInfo.environment["BLISTER_START_TAB"],
               let tab = Tab(rawValue: raw) {
                return tab
            }
            #endif
            return .aisle
        }
    }

    @State private var selection: Tab

    init(initialTab: Tab = .aisle) {
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
