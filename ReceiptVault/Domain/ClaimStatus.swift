import Foundation

/// Where a warranty claim is up to.
enum ClaimStatus: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case lodged
    case inProgress
    case resolved
    case rejected

    var id: String { rawValue }

    /// Lodged and in-progress claims are "open": the retailer or manufacturer is still dealing with them.
    var isOpen: Bool {
        switch self {
        case .lodged, .inProgress: true
        case .resolved, .rejected: false
        }
    }

    var displayName: String {
        switch self {
        case .lodged: "Lodged"
        case .inProgress: "In progress"
        case .resolved: "Resolved"
        case .rejected: "Rejected"
        }
    }
}
