import Foundation

/// What the widget shows: up to five warranties ending soon, written to the App Group by the app.
/// It stores expiry dates rather than day counts, so the widget can work out "N days left" for
/// whichever day it's drawing.
struct WarrantySnapshot: Codable, Hashable, Sendable {
    static let maximumItems = 5
    /// Same window as Expiring Soon in the app.
    static let windowInDays = 30

    struct Item: Codable, Hashable, Identifiable, Sendable {
        let id: UUID
        let itemName: String
        let retailer: String
        let warrantyKind: WarrantyKind
        let expiryDate: Date

        /// Whole calendar days from `date` to the expiry day: 0 on the last day of cover.
        func daysLeft(on date: Date, calendar: Calendar = .current) -> Int {
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
                to: calendar.startOfDay(for: expiryDate)
            ).day ?? 0
        }
    }

    var generatedAt: Date
    var items: [Item]

    init(generatedAt: Date, items: [Item]) {
        self.generatedAt = generatedAt
        self.items = Array(items.prefix(Self.maximumItems))
    }

    static let empty = WarrantySnapshot(generatedAt: .distantPast, items: [])

    /// Items still within the window on `date`, soonest first. Warranties that ended after the
    /// snapshot was written drop off at midnight without the app having to run.
    func itemsEndingSoon(on date: Date, calendar: Calendar = .current) -> [(item: Item, daysLeft: Int)] {
        items
            .map { (item: $0, daysLeft: $0.daysLeft(on: date, calendar: calendar)) }
            .filter { (0...Self.windowInDays).contains($0.daysLeft) }
            .sorted { $0.item.expiryDate < $1.item.expiryDate }
    }
}

extension WarrantySnapshot.Item {
    /// "Ends today", "1 day left", "9 days left".
    static func daysLeftLabel(_ days: Int) -> String {
        switch days {
        case 0: "Ends today"
        case 1: "1 day left"
        default: "\(days) days left"
        }
    }
}
