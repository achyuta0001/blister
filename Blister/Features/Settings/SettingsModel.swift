import Foundation
import OSLog

/// Backing state for ``SettingsView``: keeps freshly written CSV/JSON export file URLs and the
/// current photo-storage byte count. Regenerated whenever the collection changes so the share
/// sheet always hands off up-to-date files.
@MainActor
@Observable
final class SettingsModel {
    private(set) var csvURL: URL?
    private(set) var jsonURL: URL?
    private(set) var storageBytes: Int64 = 0

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                               category: "Settings")

    /// Recomputes storage size and rewrites both export files from the given cars.
    func refresh(cars: [Car]) {
        storageBytes = DocumentsPhotoStore.shared.totalBytes()
        do {
            let csv = CollectionExporter.csv(from: cars)
            csvURL = try CollectionExporter.writeTemporaryFile(
                named: "Blister-Collection.csv",
                contents: Data(csv.utf8)
            )
            let json = try CollectionArchive(cars: cars).jsonData()
            jsonURL = try CollectionExporter.writeTemporaryFile(
                named: "Blister-Collection.json",
                contents: json
            )
        } catch {
            logger.error("Failed to build export files: \(error.localizedDescription, privacy: .public)")
        }
    }
}
