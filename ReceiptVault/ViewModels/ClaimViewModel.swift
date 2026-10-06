import Foundation
import Observation

/// Lodges new warranty claims and marks open ones resolved or rejected.
@MainActor
@Observable
final class ClaimViewModel {
    var faultDescription = ""
    private(set) var isWorking = false
    var alert: ShopperAlert?

    private let lodgeWarrantyClaim: LodgeWarrantyClaim
    private let resolveClaim: ResolveClaim
    private let now: () -> Date

    init(lodgeWarrantyClaim: LodgeWarrantyClaim, resolveClaim: ResolveClaim, now: @escaping () -> Date) {
        self.lodgeWarrantyClaim = lodgeWarrantyClaim
        self.resolveClaim = resolveClaim
        self.now = now
    }

    /// Claims are always lodged today.
    var lodgedOn: Date { now() }

    var canLodge: Bool {
        !faultDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking
    }

    /// Returns true once the claim is lodged.
    func lodgeClaim(onWarrantyWithID warrantyID: UUID) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await lodgeWarrantyClaim.execute(warrantyID: warrantyID, faultDescription: faultDescription)
            return true
        } catch {
            alert = ShopperAlert(error, fallbackTitle: "Your claim couldn't be lodged.")
            return false
        }
    }

    /// Returns true once the claim is updated.
    func markClaim(withID claimID: UUID, as outcome: ResolveClaim.Outcome) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await resolveClaim.execute(claimID: claimID, outcome: outcome)
            return true
        } catch {
            alert = ShopperAlert(error, fallbackTitle: "The claim couldn't be updated.")
            return false
        }
    }
}
