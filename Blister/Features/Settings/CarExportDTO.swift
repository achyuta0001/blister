import Foundation

/// A flat, `Encodable` snapshot of a ``Car`` for export.
///
/// ``Car`` is a SwiftData `@Model` (a reference type, not `Codable`), so exports go through this
/// value type instead of encoding the model directly. Enums are exported as their stable raw
/// values; money stays as `Decimal` so JSON encodes it as a number, not a currency string.
struct CarExportDTO: Encodable {
    let id: UUID
    let castingName: String
    let brand: String
    let series: String?
    let releaseYear: Int?
    let collectorNumber: String?
    let colorway: String?
    let wheelType: String?
    let huntStatus: String
    let condition: String
    let status: String
    let purchasePriceINR: Decimal?
    let purchaseDate: Date?
    let purchaseLocation: String?
    let estimatedValueINR: Decimal?
    let notes: String?
    let barcode: String?
    let tags: [String]
    let dateAdded: Date
    let dateModified: Date

    init(car: Car) {
        id = car.id
        castingName = car.castingName
        brand = car.brand.rawValue
        series = car.series
        releaseYear = car.releaseYear
        collectorNumber = car.collectorNumber
        colorway = car.colorway
        wheelType = car.wheelType
        huntStatus = car.huntStatus.rawValue
        condition = car.condition.rawValue
        status = car.status.rawValue
        purchasePriceINR = car.purchasePriceINR
        purchaseDate = car.purchaseDate
        purchaseLocation = car.purchaseLocation
        estimatedValueINR = car.estimatedValueINR
        notes = car.notes
        barcode = car.barcode
        tags = car.tags
        dateAdded = car.dateAdded
        dateModified = car.dateModified
    }
}
