import Foundation

/// A warranty that appears on the Expiring Soon list, with the purchase details needed to show it.
struct ExpiringWarranty: Identifiable, Hashable, Sendable {
    let purchaseID: UUID
    let itemName: String
    let retailer: String
    let warranty: Warranty
    let daysRemaining: Int

    var id: UUID { warranty.id }
}

/// The domain query behind Expiring Soon and the widget.
enum ExpiringSoon {
    static let windowInDays = 30

    /// Warranties ending between the start of today and today + 30 days that have no open claim,
    /// soonest first. A warranty with an open claim is already being dealt with, so it is left out.
    static func warranties(
        in purchases: [Purchase],
        today: Date,
        calendar: Calendar = .current
    ) -> [ExpiringWarranty] {
        purchases
            .flatMap { purchase in
                purchase.warranties.compactMap { warranty -> ExpiringWarranty? in
                    let days = warranty.daysRemaining(from: today, calendar: calendar)
                    guard (0...windowInDays).contains(days), !warranty.hasOpenClaim else { return nil }
                    return ExpiringWarranty(
                        purchaseID: purchase.id,
                        itemName: purchase.itemName,
                        retailer: purchase.retailer,
                        warranty: warranty,
                        daysRemaining: days
                    )
                }
            }
            .sorted { ($0.warranty.expiryDate, $0.itemName) < ($1.warranty.expiryDate, $1.itemName) }
    }
}

extension WarrantySnapshot {
    /// The widget's copy of Expiring Soon: the five warranties ending soonest.
    init(expiring: [ExpiringWarranty], generatedAt: Date) {
        self.init(
            generatedAt: generatedAt,
            items: expiring.map {
                Item(
                    id: $0.warranty.id,
                    itemName: $0.itemName,
                    retailer: $0.retailer,
                    warrantyKind: $0.warranty.kind,
                    expiryDate: $0.warranty.expiryDate
                )
            }
        )
    }
}
