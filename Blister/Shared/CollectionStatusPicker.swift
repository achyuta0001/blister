import SwiftUI

/// Segmented Garage / Wishlist control for a car's ``CollectionStatus``, shared by Add Car and Edit
/// Car so both spell the choice the same way.
///
/// The segments are labelled with the **tab names** the user already knows ("Garage" / "Wishlist")
/// rather than the raw `Owned` / `Wanted` enum names, because the question being asked is "where does
/// this car go?" — and because the Add Car form already has an unrelated `Picker` titled "Hunt
/// status"; two rows reading "… status" would be easy to mix up.
///
/// The caption is drawn explicitly instead of relying on the `Picker` label: inside a `Form`, a
/// `.segmented` picker hides its own label.
struct CollectionStatusPicker: View {
    let title: String
    @Binding var selection: CollectionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignTokens.secondaryText)
            Picker(title, selection: $selection) {
                Text(String(localized: "Garage")).tag(CollectionStatus.owned)
                Text(String(localized: "Wishlist")).tag(CollectionStatus.wanted)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.vertical, DesignTokens.spacingXS)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }
}

#Preview {
    @Previewable @State var status: CollectionStatus = .wanted
    Form {
        Section(String(localized: "Details")) {
            CollectionStatusPicker(title: String(localized: "Add to"), selection: $status)
        }
    }
    .preferredColorScheme(.dark)
}
