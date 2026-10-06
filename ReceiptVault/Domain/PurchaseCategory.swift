import Foundation

/// What kind of item a purchase is.
/// Raw values are persisted, so never change an existing raw value.
enum PurchaseCategory: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case electronics
    case appliances
    case furniture
    case tools
    case sportsAndOutdoors
    case clothing
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .electronics: "Electronics"
        case .appliances: "Home appliances"
        case .furniture: "Furniture"
        case .tools: "Tools"
        case .sportsAndOutdoors: "Sports & outdoors"
        case .clothing: "Clothing"
        case .other: "Other"
        }
    }
}
