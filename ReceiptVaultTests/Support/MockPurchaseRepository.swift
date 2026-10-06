import Foundation
@testable import ReceiptVault

enum MockStorageError: Error {
    case unavailable
}

/// In-memory PurchaseRepository for tests. Records every write and can be told to fail.
actor MockPurchaseRepository: PurchaseRepository {
    private(set) var purchases: [Purchase]
    private(set) var savedPurchases: [Purchase] = []
    private(set) var deletedPurchaseIDs: [UUID] = []
    private(set) var addedClaims: [(claim: WarrantyClaim, warrantyID: UUID)] = []
    private(set) var updatedClaims: [WarrantyClaim] = []

    private var readError: Error?
    private var writeError: Error?

    init(purchases: [Purchase] = []) {
        self.purchases = purchases
    }

    /// Every fetch throws from now on.
    func failReads(with error: Error = MockStorageError.unavailable) {
        readError = error
    }

    /// Every save, delete, addClaim and updateClaim throws from now on.
    func failWrites(with error: Error = MockStorageError.unavailable) {
        writeError = error
    }

    // MARK: PurchaseRepository

    func fetchAllPurchases() throws -> [Purchase] {
        if let readError { throw readError }
        return purchases
    }

    func fetchPurchase(id: UUID) throws -> Purchase? {
        if let readError { throw readError }
        return purchases.first { $0.id == id }
    }

    func fetchWarranty(id: UUID) throws -> Warranty? {
        if let readError { throw readError }
        return purchases.flatMap(\.warranties).first { $0.id == id }
    }

    func fetchClaim(id: UUID) throws -> WarrantyClaim? {
        if let readError { throw readError }
        return purchases.flatMap(\.warranties).flatMap(\.claims).first { $0.id == id }
    }

    func fetchExpiringWarranties(today: Date, calendar: Calendar) throws -> [ExpiringWarranty] {
        if let readError { throw readError }
        return ExpiringSoon.warranties(in: purchases, today: today, calendar: calendar)
    }

    func save(_ purchase: Purchase) throws {
        if let writeError { throw writeError }
        savedPurchases.append(purchase)
        if let index = purchases.firstIndex(where: { $0.id == purchase.id }) {
            purchases[index] = purchase
        } else {
            purchases.append(purchase)
        }
    }

    func deletePurchase(id: UUID) throws {
        if let writeError { throw writeError }
        deletedPurchaseIDs.append(id)
        purchases.removeAll { $0.id == id }
    }

    func addClaim(_ claim: WarrantyClaim, toWarrantyWithID warrantyID: UUID) throws {
        if let writeError { throw writeError }
        addedClaims.append((claim, warrantyID))
        for p in purchases.indices {
            for w in purchases[p].warranties.indices where purchases[p].warranties[w].id == warrantyID {
                purchases[p].warranties[w].claims.append(claim)
            }
        }
    }

    func updateClaim(_ claim: WarrantyClaim) throws {
        if let writeError { throw writeError }
        updatedClaims.append(claim)
        for p in purchases.indices {
            for w in purchases[p].warranties.indices {
                for c in purchases[p].warranties[w].claims.indices where purchases[p].warranties[w].claims[c].id == claim.id {
                    purchases[p].warranties[w].claims[c] = claim
                }
            }
        }
    }
}
