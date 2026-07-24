import Foundation

/// A versioned, `Codable` snapshot of the whole collection for JSON export/import (spec §6.6).
///
/// Serialization lives here — pure and view-free — so it can be unit tested and reused. The SwiftData
/// merge that consumes a decoded archive lives in ``CollectionImporter``. Photos are device-local:
/// the archive records each car's `photoFilenames` but never the image bytes.
struct CollectionArchive: Codable, Equatable {
    /// Schema version, so a future importer can migrate older archives.
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var cars: [CarRecord]

    init(cars: [Car], exportedAt: Date = Date()) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.cars = cars.map(CarRecord.init)
    }

    // MARK: - Serialization

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func jsonData() throws -> Data {
        try Self.makeEncoder().encode(self)
    }

    static func decode(from data: Data) throws -> CollectionArchive {
        try makeDecoder().decode(CollectionArchive.self, from: data)
    }

    // MARK: - Merge policy

    /// Last-writer-wins: an incoming record replaces an existing car only when it is at least as
    /// recently modified. Pure so the merge decision can be unit tested without SwiftData.
    static func shouldOverwrite(incoming: CarRecord, existingDateModified: Date) -> Bool {
        incoming.dateModified >= existingDateModified
    }
}
