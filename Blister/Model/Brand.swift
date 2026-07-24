import Foundation

enum Brand: String, Codable, CaseIterable, Identifiable {
    case hotWheels, matchbox, miniGT, majorette, tomica, tarmacWorks, m2, greenlight, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hotWheels:    return String(localized: "Hot Wheels")
        case .matchbox:     return String(localized: "Matchbox")
        case .miniGT:       return String(localized: "Mini GT")
        case .majorette:    return String(localized: "Majorette")
        case .tomica:       return String(localized: "Tomica")
        case .tarmacWorks:  return String(localized: "Tarmac Works")
        case .m2:           return String(localized: "M2 Machines")
        case .greenlight:   return String(localized: "Greenlight")
        case .other:        return String(localized: "Other")
        }
    }
}
