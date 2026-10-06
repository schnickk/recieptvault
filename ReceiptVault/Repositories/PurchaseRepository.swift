import Foundation

/// Where purchases, warranties and claims are kept. Use cases depend on this protocol only,
/// so they never know about Core Data and tests can swap in a mock.
protocol PurchaseRepository: Sendable {
    func fetchAllPurchases() async throws -> [Purchase]
    func fetchPurchase(id: UUID) async throws -> Purchase?
    func fetchWarranty(id: UUID) async throws -> Warranty?
    func fetchClaim(id: UUID) async throws -> WarrantyClaim?
    /// The Expiring Soon domain query: warranties ending between the start of `today` and
    /// 30 days later with no open claim, soonest first.
    func fetchExpiringWarranties(today: Date, calendar: Calendar) async throws -> [ExpiringWarranty]
    /// Inserts the purchase, or replaces the stored one with the same id.
    func save(_ purchase: Purchase) async throws
    func deletePurchase(id: UUID) async throws
    func addClaim(_ claim: WarrantyClaim, toWarrantyWithID warrantyID: UUID) async throws
    /// Replaces the stored claim with the same id.
    func updateClaim(_ claim: WarrantyClaim) async throws
}
