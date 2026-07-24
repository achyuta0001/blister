import Foundation

/// A flat, `Codable` snapshot of a single ``Car`` for the JSON export/import archive (spec §6.6).
///
/// ``Car`` is a SwiftData `@Model` reference type and isn't `Codable`, so the archive round-trips
/// through this value type. Enums are stored as their stable raw values; money stays as `Decimal` so
/// JSON encodes it as a number, never a `Double` or a currency string. `photoFilenames` are recorded
/// so a car's image references survive a round trip on the same device, but the image bytes
/// themselves are device-local and are not part of the archive.
struct CarRecord: Codable, Equatable {
    var id: UUID
    var castingName: String
    var brand: String
    var series: String?
    var releaseYear: Int?
    var collectorNumber: String?
    var colorway: String?
    var wheelType: String?
    var huntStatus: String
    var condition: String
    var status: String
    var purchasePriceINR: Decimal?
    var purchaseDate: Date?
    var purchaseLocation: String?
    var estimatedValueINR: Decimal?
    var notes: String?
    var barcode: String?
    var photoFilenames: [String]
    var tags: [String]
    var dateAdded: Date
    var dateModified: Date

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
        photoFilenames = car.photoFilenames
        tags = car.tags
        dateAdded = car.dateAdded
        dateModified = car.dateModified
    }

    /// Builds a fresh ``Car`` from this record. Unknown/removed enum raw values fall back to safe
    /// defaults so a slightly-newer export never fails to import.
    func makeCar() -> Car {
        let car = Car(
            id: id,
            castingName: castingName,
            brand: Brand(rawValue: brand) ?? .other,
            series: series,
            releaseYear: releaseYear,
            collectorNumber: collectorNumber,
            colorway: colorway,
            wheelType: wheelType,
            huntStatus: HuntStatus(rawValue: huntStatus) ?? .none,
            condition: Condition(rawValue: condition) ?? .mintOnCard,
            status: CollectionStatus(rawValue: status) ?? .owned,
            purchasePriceINR: purchasePriceINR,
            purchaseDate: purchaseDate,
            purchaseLocation: purchaseLocation,
            estimatedValueINR: estimatedValueINR,
            notes: notes,
            barcode: barcode,
            photoFilenames: photoFilenames,
            tags: tags,
            dateAdded: dateAdded,
            dateModified: dateModified
        )
        car.recomputeSearchKey()
        return car
    }

    /// Overwrites an existing car's fields with this record's values (import merge). Recomputes the
    /// denormalised search key so search stays consistent.
    func apply(to car: Car) {
        car.castingName = castingName
        car.brand = Brand(rawValue: brand) ?? .other
        car.series = series
        car.releaseYear = releaseYear
        car.collectorNumber = collectorNumber
        car.colorway = colorway
        car.wheelType = wheelType
        car.huntStatus = HuntStatus(rawValue: huntStatus) ?? .none
        car.condition = Condition(rawValue: condition) ?? .mintOnCard
        car.status = CollectionStatus(rawValue: status) ?? .owned
        car.purchasePriceINR = purchasePriceINR
        car.purchaseDate = purchaseDate
        car.purchaseLocation = purchaseLocation
        car.estimatedValueINR = estimatedValueINR
        car.notes = notes
        car.barcode = barcode
        car.photoFilenames = photoFilenames
        car.tags = tags
        car.dateAdded = dateAdded
        car.dateModified = dateModified
        car.recomputeSearchKey()
    }
}
