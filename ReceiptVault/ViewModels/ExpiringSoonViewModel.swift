import Foundation
import Observation

/// Warranties ending in the next 30 days with no open claim, soonest first.
@MainActor
@Observable
final class ExpiringSoonViewModel {
    private(set) var warranties: [ExpiringWarranty] = []
    private(set) var hasLoaded = false
    var alert: ShopperAlert?

    private let repository: any PurchaseRepository
    private let now: () -> Date
    private let calendar: Calendar

    init(repository: any PurchaseRepository, now: @escaping () -> Date, calendar: Calendar) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
    }

    func load() async {
        do {
            warranties = try await repository.fetchExpiringWarranties(today: now(), calendar: calendar)
        } catch {
            alert = ShopperAlert(
                error,
                fallbackTitle: "Expiring warranties couldn't be loaded.",
                fallbackMessage: "Pull down to try again."
            )
        }
        hasLoaded = true
    }

    func daysLeftLabel(for item: ExpiringWarranty) -> String {
        WarrantyStatus.endingSoon(daysRemaining: item.daysRemaining).daysLeftLabel ?? ""
    }
}
