import SwiftUI
import SwiftData

/// Settings (spec §6.6): export the collection as CSV or JSON via the share sheet, a photo-storage
/// readout, and the app version.
struct SettingsView: View {
    @Query(sort: \Car.dateAdded, order: .reverse) private var cars: [Car]
    @State private var model = SettingsModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let url = model.csvURL {
                        ShareLink(item: url) {
                            exportRow(
                                title: String(localized: "Export as CSV"),
                                subtitle: String(localized: "Opens in Numbers, values intact"),
                                systemImage: "tablecells"
                            )
                        }
                    }
                    if let url = model.jsonURL {
                        ShareLink(item: url) {
                            exportRow(
                                title: String(localized: "Export as JSON"),
                                subtitle: String(localized: "Full collection data"),
                                systemImage: "curlybraces"
                            )
                        }
                    }
                } header: {
                    Text(String(localized: "Export"))
                } footer: {
                    Text(String(localized: "\(cars.count) cars will be included."))
                }

                Section {
                    LabeledContent(
                        String(localized: "Photo storage"),
                        value: model.storageBytes.formatted(.byteCount(style: .file))
                    )
                } header: {
                    Text(String(localized: "Storage"))
                } footer: {
                    Text(String(localized: "Photos are stored on this device only."))
                }

                Section(String(localized: "About")) {
                    LabeledContent(String(localized: "Version"), value: AppInfo.versionString)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.background)
            .foregroundStyle(DesignTokens.primaryText)
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.large)
        }
        .task { model.refresh(cars: cars) }
        .onChange(of: cars.count) { model.refresh(cars: cars) }
    }

    private func exportRow(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(title)
                    .foregroundStyle(DesignTokens.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(DesignTokens.accent)
        }
        .frame(minHeight: DesignTokens.minTapTarget)
    }
}

#Preview {
    SettingsView()
        .modelContainer(.inMemory(seeded: true))
        .preferredColorScheme(.dark)
}
