import Foundation
import Observation

/// Holds every purchase for My Purchases and Purchase Detail.
@MainActor
@Observable
final class PurchaseListViewModel {
    struct MonthSection: Identifiable {
        let id: Date
        let title: String
        let purchases: [Purchase]
    }

    private(set) var purchases: [Purchase] = []
    private(set) var hasLoaded = false
    var alert: ShopperAlert?

    private let repository: any PurchaseRepository
    private let receiptFileURL: (String) -> URL?
    private let now: () -> Date
    private let calendar: Calendar

    init(
        repository: any PurchaseRepository,
        receiptFileURL: @escaping (String) -> URL?,
        now: @escaping () -> Date,
        calendar: Calendar
    ) {
        self.repository = repository
        self.receiptFileURL = receiptFileURL
        self.now = now
        self.calendar = calendar
    }

    /// Purchases grouped by the month they were bought, newest first.
    var sections: [MonthSection] {
        let byMonth = Dictionary(grouping: purchases) { purchase in
            calendar.dateInterval(of: .month, for: purchase.purchaseDate)?.start ?? purchase.purchaseDate
        }
        return byMonth.keys.sorted(by: >).map { month in
            MonthSection(
                id: month,
                title: month.formatted(.dateTime.month(.wide).year()),
                purchases: byMonth[month, default: []].sorted { $0.purchaseDate > $1.purchaseDate }
            )
        }
    }

    func load() async {
        do {
            purchases = try await repository.fetchAllPurchases()
        } catch {
            alert = ShopperAlert(
                error,
                fallbackTitle: "Your purchases couldn't be loaded.",
                fallbackMessage: "Pull down to try again. If it keeps happening, close and reopen Receipt Vault."
            )
        }
        hasLoaded = true
    }

    func purchase(withID id: UUID) -> Purchase? {
        purchases.first { $0.id == id }
    }

    func status(of purchase: Purchase) -> WarrantyStatus {
        purchase.warrantyStatus(on: now(), calendar: calendar)
    }

    func status(of warranty: Warranty) -> WarrantyStatus {
        warranty.status(on: now(), calendar: calendar)
    }

    func canLodgeClaim(on warranty: Warranty) -> Bool {
        warranty.isActive(on: now(), calendar: calendar) && !warranty.hasOpenClaim
    }

    /// The receipt file to preview, or nil if there's no receipt or the file is missing.
    func receiptURL(for purchase: Purchase) -> URL? {
        guard let fileName = purchase.receiptFileName, let url = receiptFileURL(fileName) else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
