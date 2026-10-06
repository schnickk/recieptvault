import Foundation

/// Who provides the warranty cover.
enum WarrantyKind: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case manufacturer
    case extended

    var id: String { rawValue }

    /// "Manufacturer warranty" / "Extended warranty".
    var displayName: String {
        switch self {
        case .manufacturer: "Manufacturer warranty"
        case .extended: "Extended warranty"
        }
    }

    /// Shown once cover has finished. Always "… warranty ended", never "Not covered",
    /// because the shopper may still have rights under the Australian Consumer Law.
    var endedLabel: String { "\(displayName) ended" }
}
