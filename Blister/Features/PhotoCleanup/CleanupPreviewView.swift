import SwiftUI

/// Before/after chooser for on-device photo cleanup (spec §6.3 / §6.4). Presented as a sheet after
/// `PhotoCleanup.cleaned(_:)` returns a non-nil result. The user compares the original snap against
/// the cleaned one and picks one; nothing is persisted here — the callbacks hand the decision back
/// to the caller, which owns saving.
///
/// "Cleaned" is not one fixed look: a **carded** photo comes back as the deskewed card alone, at the
/// card's own aspect, while a **loose** casting comes back composited onto the square studio
/// backdrop. Which one the user is looking at depends on the photo, so the view sizes the image with
/// `.scaledToFit()` rather than assuming a square.
struct CleanupPreviewView: View {
    /// Which image the toggle is currently showing.
    private enum Variant: Hashable {
        case original
        case cleaned
    }

    private let original: UIImage
    private let cleaned: UIImage
    private let onUse: (UIImage) -> Void
    private let onKeepOriginal: () -> Void

    @State private var variant: Variant = .cleaned
    @Environment(\.dismiss) private var dismiss

    init(
        original: UIImage,
        cleaned: UIImage,
        onUse: @escaping (UIImage) -> Void,
        onKeepOriginal: @escaping () -> Void
    ) {
        self.original = original
        self.cleaned = cleaned
        self.onUse = onUse
        self.onKeepOriginal = onKeepOriginal
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignTokens.spacingL) {
                Picker(String(localized: "Photo variant"), selection: $variant) {
                    Text(String(localized: "Original")).tag(Variant.original)
                    Text(String(localized: "Cleaned")).tag(Variant.cleaned)
                }
                .pickerStyle(.segmented)

                Image(uiImage: variant == .cleaned ? cleaned : original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(
                        variant == .cleaned
                            ? Text(String(localized: "Cleaned photo"))
                            : Text(String(localized: "Original photo"))
                    )

                VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                    Button {
                        onUse(cleaned)
                        dismiss()
                    } label: {
                        Text(String(localized: "Use cleaned"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onKeepOriginal()
                        dismiss()
                    } label: {
                        Text(String(localized: "Keep original"))
                            .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(DesignTokens.spacingM)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DesignTokens.background)
            .navigationTitle(String(localized: "Clean up photo"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let placeholder = UIImage(systemName: "car.fill") ?? UIImage()
    return CleanupPreviewView(
        original: placeholder,
        cleaned: placeholder,
        onUse: { _ in },
        onKeepOriginal: {}
    )
    .preferredColorScheme(.dark)
}
