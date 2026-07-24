import Foundation
import SwiftData

/// Merges a decoded ``CollectionArchive`` into the SwiftData store (spec §6.6). Kept thin — all the
/// testable logic (decode + last-writer-wins policy) lives in ``CollectionArchive`` / ``CarRecord``.
enum CollectionImporter {

    /// Outcome of an import, for a brief user-facing summary.
    struct Summary: Equatable {
        var inserted: Int
        var updated: Int
        var skipped: Int
    }

    /// Decodes `data` and merges it into `context`, matching on `id`: an unseen id is inserted, and a
    /// matching id is overwritten only when the incoming record is at least as recent
    /// (last-writer-wins). Returns a count summary.
    @discardableResult
    static func merge(from data: Data, into context: ModelContext) throws -> Summary {
        let archive = try CollectionArchive.decode(from: data)
        let existing = try context.fetch(FetchDescriptor<Car>())
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var summary = Summary(inserted: 0, updated: 0, skipped: 0)
        for record in archive.cars {
            if let current = byID[record.id] {
                if CollectionArchive.shouldOverwrite(incoming: record, existingDateModified: current.dateModified) {
                    record.apply(to: current)
                    summary.updated += 1
                } else {
                    summary.skipped += 1
                }
            } else {
                let car = record.makeCar()
                context.insert(car)
                byID[car.id] = car
                summary.inserted += 1
            }
        }
        try context.save()
        return summary
    }
}
