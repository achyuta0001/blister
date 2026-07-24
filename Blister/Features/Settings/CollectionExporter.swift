import Foundation
import OSLog

/// Builds shareable CSV and JSON exports of the collection (spec §6.6).
///
/// CSV is RFC 4180: a header row, fields quoted/escaped when they contain commas, quotes, or
/// newlines, and money written as plain locale-independent decimals ("1200", "1200.5") so Numbers
/// parses the columns as numbers rather than text. JSON encodes ``CarExportDTO`` values with
/// ISO 8601 dates.
enum CollectionExporter {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                      category: "Export")

    /// Column order shared by the header and every row.
    private static let headers = [
        "id", "castingName", "brand", "series", "releaseYear", "collectorNumber",
        "colorway", "wheelType", "huntStatus", "condition", "status", "purchasePriceINR",
        "purchaseDate", "purchaseLocation", "estimatedValueINR", "notes", "barcode",
        "tags", "dateAdded", "dateModified"
    ]

    // MARK: - CSV

    static func csv(from cars: [Car]) -> String {
        var lines: [String] = [headers.map(escape).joined(separator: ",")]
        for car in cars {
            let fields: [String] = [
                car.id.uuidString,
                car.castingName,
                car.brand.rawValue,
                car.series ?? "",
                car.releaseYear.map(String.init) ?? "",
                car.collectorNumber ?? "",
                car.colorway ?? "",
                car.wheelType ?? "",
                car.huntStatus.rawValue,
                car.condition.rawValue,
                car.status.rawValue,
                plainDecimal(car.purchasePriceINR),
                iso(car.purchaseDate),
                car.purchaseLocation ?? "",
                plainDecimal(car.estimatedValueINR),
                car.notes ?? "",
                car.barcode ?? "",
                car.tags.joined(separator: ";"),
                iso(car.dateAdded),
                iso(car.dateModified)
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        // RFC 4180 uses CRLF line endings; Numbers and Excel both accept them.
        return lines.joined(separator: "\r\n")
    }

    // MARK: - JSON

    static func jsonData(from cars: [Car]) throws -> Data {
        let dtos = cars.map(CarExportDTO.init)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(dtos)
    }

    // MARK: - File writing

    /// Writes `contents` to a uniquely named temp directory so the share sheet can hand off a real
    /// file URL. A fresh subdirectory avoids clobbering a previous export still being shared.
    static func writeTemporaryFile(named name: String, contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Formatting helpers

    /// Money as a plain, parseable decimal: no grouping separators, no currency symbol, and a fixed
    /// `.` decimal separator (via `en_US_POSIX`) so Numbers reads the column as a number.
    static func plainDecimal(_ amount: Decimal?) -> String {
        guard let amount else { return "" }
        return amount.formatted(
            .number
                .grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }

    private static func iso(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(.iso8601)
    }

    /// RFC 4180 field escaping: wrap in quotes and double any embedded quotes when the value
    /// contains a comma, quote, or line break.
    static func escape(_ field: String) -> String {
        let needsQuoting = field.contains { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
