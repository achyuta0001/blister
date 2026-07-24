import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import OSLog

/// Settings (spec §6.6): export the collection as CSV or JSON via the share sheet, import a JSON
/// snapshot back in, a photo-storage readout, and the app version.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Car.dateAdded, order: .reverse) private var cars: [Car]
    @State private var model = SettingsModel()

    /// Drives the JSON `fileImporter`.
    @State private var showImporter = false
    /// Non-nil after a successful import; shows a short summary alert.
    @State private var importSummary: CollectionImporter.Summary?
    /// Non-nil when import failed, surfaced via the shared error alert.
    @State private var importError: ErrorAlert?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                               category: "Settings")

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
                    Text(String(localized: "\(cars.count) cars will be included. Photos stay on this device and aren’t part of the file."))
                }

                Section {
                    Button {
                        showImporter = true
                    } label: {
                        exportRow(
                            title: String(localized: "Import from JSON"),
                            subtitle: String(localized: "Merge a JSON snapshot back in"),
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(String(localized: "Import"))
                } footer: {
                    Text(String(localized: "Cars are matched by ID; the most recently edited version wins."))
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
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .errorAlert($importError)
            .alert(
                String(localized: "Import Complete"),
                isPresented: Binding(
                    get: { importSummary != nil },
                    set: { presented in if !presented { importSummary = nil } }
                ),
                presenting: importSummary
            ) { _ in
                Button(String(localized: "OK"), role: .cancel) {}
            } message: { summary in
                Text(String(localized: "Added \(summary.inserted), updated \(summary.updated), skipped \(summary.skipped)."))
            }
        }
        .task { model.refresh(cars: cars) }
        .onChange(of: cars.count) { model.refresh(cars: cars) }
    }

    /// Reads the picked JSON file and merges it into the store. Uses security-scoped access because a
    /// document picker hands back a URL outside the app sandbox.
    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let summary = try CollectionImporter.merge(from: data, into: modelContext)
            importSummary = summary
            model.refresh(cars: cars)
        } catch {
            logger.error("Import failed: \(error.localizedDescription, privacy: .public)")
            importError = ErrorAlert(
                title: String(localized: "Import Failed"),
                message: String(localized: "That file couldn’t be imported. Make sure it’s a Blister JSON export.")
            )
        }
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
