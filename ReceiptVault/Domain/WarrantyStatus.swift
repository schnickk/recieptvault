import Foundation

/// How a warranty, or a whole purchase, stands on a given day.
enum WarrantyStatus: Hashable, Sendable {
    /// More than 30 days of cover left.
    case active(daysRemaining: Int)
    /// 0–30 days left. The same window as Expiring Soon.
    case endingSoon(daysRemaining: Int)
    case ended(kind: WarrantyKind, endedOn: Date)
    case noWarranty

    /// Short label for the status pill.
    var label: String {
        switch self {
        case .active:
            "Active"
        case let .endingSoon(days):
            switch days {
            case 0: "Ends today"
            case 1: "Ending in 1 day"
            default: "Ending in \(days) days"
            }
        case let .ended(kind, _):
            kind.endedLabel
        case .noWarranty:
            "No warranty"
        }
    }

    /// Days-left wording for detail rows, e.g. "128 days left". Nil once the warranty has ended.
    var daysLeftLabel: String? {
        switch self {
        case let .active(days), let .endingSoon(days):
            switch days {
            case 0: "Ends today"
            case 1: "1 day left"
            default: "\(days) days left"
            }
        case .ended, .noWarranty:
            nil
        }
    }
}

/// What Receipt Vault tells a shopper whose warranty has ended. Warranty cover ending doesn't
/// end their consumer guarantees, so the app never says "Not covered".
enum ConsumerLaw {
    static let advice = "You may still be covered under the Australian Consumer Law. Contact the retailer directly."
}

extension Warranty {
    func status(on date: Date, calendar: Calendar = .current) -> WarrantyStatus {
        let days = daysRemaining(from: date, calendar: calendar)
        if days < 0 { return .ended(kind: kind, endedOn: expiryDate) }
        if days <= ExpiringSoon.windowInDays { return .endingSoon(daysRemaining: days) }
        return .active(daysRemaining: days)
    }
}

extension Purchase {
    /// One status for the whole purchase: the active warranty that ends soonest or,
    /// if every warranty has ended, the one that ended most recently.
    func warrantyStatus(on date: Date, calendar: Calendar = .current) -> WarrantyStatus {
        let soonestActive = warranties
            .filter { $0.isActive(on: date, calendar: calendar) }
            .min { $0.expiryDate < $1.expiryDate }
        if let soonestActive {
            return soonestActive.status(on: date, calendar: calendar)
        }
        if let lastEnded = warranties.max(by: { $0.expiryDate < $1.expiryDate }) {
            return lastEnded.status(on: date, calendar: calendar)
        }
        return .noWarranty
    }
}
