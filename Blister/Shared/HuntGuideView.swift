import SwiftUI

/// What a Treasure Hunt actually is — the screen the terse line in the Garage hunt filter points at.
///
/// Deliberately carries no `NavigationStack` of its own because it is shown two ways: pushed from
/// Settings ▸ About, and presented as a sheet from ``GarageFilterBar`` (which supplies the dismiss
/// control). Names and badges are read from ``HuntStatus`` so this screen can never drift away from
/// the badges on the grid cards.
struct HuntGuideView: View {
    var body: some View {
        List {
            Section {
                Text(String(localized: "Mattel hides a few rare cars in ordinary cases. They hang on the same peg at the same price as everything else — spotting one first is the whole game."))
                    .foregroundStyle(DesignTokens.secondaryText)
            }

            Section {
                Text(String(localized: "Looks like any other car in the case: ordinary paint, ordinary plastic wheels."))
                Text(String(localized: "The only tell is a small flame logo, printed on the car or tucked into the card art."))
            } header: {
                header(for: .treasureHunt)
            } footer: {
                Text(String(localized: "About one case in ten holds one."))
            }

            Section {
                Text(String(localized: "Spectraflame paint — deep and candy-like over polished metal."))
                Text(String(localized: "Real Riders: proper rubber tyres instead of plastic."))
                Text(String(localized: "A TH logo on the card, plus a gold-and-silver $TH flame."))
            } header: {
                header(for: .superTreasureHunt)
            } footer: {
                Text(String(localized: "About one case in two or three holds one. This is the valuable one."))
            }

            Section {
                Text(String(localized: "Check the wheels through the blister first — rubber sidewalls give a Super away at arm’s length. Then look for the flame: a plain hunt has nothing else to give it away, so it is the one people walk straight past."))
            } header: {
                plainHeader(String(localized: "On the peg"))
            }

            Section {
                Text(String(localized: "Tagging a car badges it in your garage and feeds the Hunt filter, so you can pull up everything you have found — and so a $TH is never priced like the mainline it resembles."))
            } header: {
                plainHeader(String(localized: "Why tag them"))
            }
        }
        .foregroundStyle(DesignTokens.primaryText)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.background)
        .navigationTitle(String(localized: "Treasure Hunts"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Section header carrying the same accent badge the grid cards use, then the full name.
    private func header(for status: HuntStatus) -> some View {
        HStack(spacing: DesignTokens.spacingS) {
            if let badge = status.badge {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(DesignTokens.accent, in: Capsule())
                    .foregroundStyle(DesignTokens.background)
            }
            Text(status.displayName)
                .foregroundStyle(DesignTokens.primaryText)
        }
        .font(.footnote.weight(.semibold))
        // Headers uppercase themselves by default, which would turn "$TH" into a shout.
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }

    private func plainHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(DesignTokens.primaryText)
            .textCase(nil)
    }
}

#Preview {
    NavigationStack {
        HuntGuideView()
    }
    .preferredColorScheme(.dark)
}
