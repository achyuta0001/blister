import Foundation
import SwiftData

/// A single die-cast car in the collection.
///
/// Every stored property has a default value so CloudKit sync (v2) can be enabled without a
/// destructive migration, and no property uses `@Attribute(.unique)` (CloudKit rejects it).
/// `searchKey` is denormalised and recomputed on every save via ``recomputeSearchKey()`` — see §5.
@Model
final class Car {
    var id: UUID = UUID()
    var castingName: String = ""            // "'67 Camaro"
    var brand: Brand = Brand.hotWheels
    var series: String?                     // "Car Culture: Japan Historics"
    var releaseYear: Int?
    var collectorNumber: String?            // "142/250"
    var colorway: String?                   // "Spectraflame Blue"
    var wheelType: String?                  // "RR", "5SP"
    var huntStatus: HuntStatus = HuntStatus.none
    var condition: Condition = Condition.mintOnCard
    var status: CollectionStatus = CollectionStatus.owned
    var purchasePriceINR: Decimal?
    var purchaseDate: Date?
    var purchaseLocation: String?           // "Hamleys Phoenix Mall" / seller handle
    var estimatedValueINR: Decimal?
    var notes: String?
    var barcode: String?
    var photoFilenames: [String] = []       // relative to Documents/photos/
    var tags: [String] = []
    var dateAdded: Date = Date()
    var dateModified: Date = Date()
    var searchKey: String = ""              // denormalised, recomputed on save — see §5
    var castingKey: String = ""             // normalised casting name, recomputed on save — see §5

    init(
        id: UUID = UUID(),
        castingName: String = "",
        brand: Brand = .hotWheels,
        series: String? = nil,
        releaseYear: Int? = nil,
        collectorNumber: String? = nil,
        colorway: String? = nil,
        wheelType: String? = nil,
        huntStatus: HuntStatus = .none,
        condition: Condition = .mintOnCard,
        status: CollectionStatus = .owned,
        purchasePriceINR: Decimal? = nil,
        purchaseDate: Date? = nil,
        purchaseLocation: String? = nil,
        estimatedValueINR: Decimal? = nil,
        notes: String? = nil,
        barcode: String? = nil,
        photoFilenames: [String] = [],
        tags: [String] = [],
        dateAdded: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.castingName = castingName
        self.brand = brand
        self.series = series
        self.releaseYear = releaseYear
        self.collectorNumber = collectorNumber
        self.colorway = colorway
        self.wheelType = wheelType
        self.huntStatus = huntStatus
        self.condition = condition
        self.status = status
        self.purchasePriceINR = purchasePriceINR
        self.purchaseDate = purchaseDate
        self.purchaseLocation = purchaseLocation
        self.estimatedValueINR = estimatedValueINR
        self.notes = notes
        self.barcode = barcode
        self.photoFilenames = photoFilenames
        self.tags = tags
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.searchKey = ""
        self.castingKey = ""
        recomputeSearchKey()
    }
}
