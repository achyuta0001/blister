import SwiftUI

/// A text field that suggests values already present in the user's own collection (spec §6.3):
/// casting name, series, and colorway. Suggestions appear as tappable chips below the field while
/// it is focused and the query is a partial match.
struct AutocompleteField: View {
    let title: String
    @Binding var text: String
    /// Distinct existing values for this field, drawn from the collection via `@Query`.
    let suggestions: [String]

    @FocusState private var isFocused: Bool

    private var matches: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return suggestions
            .filter { $0.lowercased().contains(query) && $0.lowercased() != query }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            TextField(title, text: $text)
                .focused($isFocused)
                .autocorrectionDisabled()

            if isFocused, !matches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingS) {
                        ForEach(matches, id: \.self) { suggestion in
                            Button {
                                text = suggestion
                                isFocused = false
                            } label: {
                                Text(suggestion)
                                    .font(.footnote)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
            }
        }
    }
}
