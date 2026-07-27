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
///
/// The segments are floored at ``DesignTokens/minTapTarget``. UIKit's own segmented metric is 32pt,
/// so this is a deliberate departure from the platform default: the project's token (spec §7
/// accessibility) is enforced on every other control in the same form, and a 32pt row next to 44pt
/// neighbours is both the smaller target and the visibly odd one out. Padding the enclosing `VStack`
/// does not do this — it grows the form row while leaving the segments' hit area at 32pt.
///
/// `.accessibilityElement(children: .contain)` (**not** `.combine`) keeps each segment individually
/// reachable to VoiceOver while the container still announces the caption; combining here would
/// collapse the choice into one unusable element.
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
            .frame(minHeight: DesignTokens.minTapTarget)
            .contentShape(Rectangle())
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
