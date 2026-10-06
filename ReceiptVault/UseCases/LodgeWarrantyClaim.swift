import Foundation

enum LodgeWarrantyClaimError: LocalizedError, Equatable {
    case warrantyNotFound
    case warrantyEnded(endedOn: Date)
    case openClaimAlreadyExists(lodgedOn: Date)
    case couldNotSave

    var errorDescription: String? {
        switch self {
        case .warrantyNotFound:
            "We couldn't find this warranty."
        case let .warrantyEnded(endedOn):
            "This warranty ended on \(endedOn.shopperFormatted). \(ConsumerLaw.advice)"
        case let .openClaimAlreadyExists(lodgedOn):
            "This warranty already has an open claim, lodged on \(lodgedOn.shopperFormatted)."
        case .couldNotSave:
            "Your claim couldn't be lodged."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .warrantyNotFound:
            "It may have been removed along with its purchase. Go back to My Purchases and try again."
        case .warrantyEnded:
            "Take your receipt when you contact the retailer. It's your proof of purchase."
        case .openClaimAlreadyExists:
            "Wait until that claim is resolved or rejected before lodging another. You can update it from the purchase's details."
        case .couldNotSave:
            "Your fault description hasn't been lost. Try again in a moment."
        }
    }
}

/// Lodges a new claim against a warranty that is still active and has no open claim.
struct LodgeWarrantyClaim: Sendable {
    let repository: any PurchaseRepository
    let snapshotPublisher: any WarrantySnapshotPublisher
    let now: @Sendable () -> Date
    let calendar: Calendar

    init(
        repository: any PurchaseRepository,
        snapshotPublisher: any WarrantySnapshotPublisher,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.snapshotPublisher = snapshotPublisher
        self.now = now
        self.calendar = calendar
    }

    @discardableResult
    func execute(warrantyID: UUID, faultDescription: String) async throws -> WarrantyClaim {
        let found: Warranty?
        do {
            found = try await repository.fetchWarranty(id: warrantyID)
        } catch {
            throw LodgeWarrantyClaimError.couldNotSave
        }
        guard let warranty = found else {
            throw LodgeWarrantyClaimError.warrantyNotFound
        }

        let today = now()
        guard warranty.isActive(on: today, calendar: calendar) else {
            throw LodgeWarrantyClaimError.warrantyEnded(endedOn: warranty.expiryDate)
        }
        if let openClaim = warranty.openClaim {
            throw LodgeWarrantyClaimError.openClaimAlreadyExists(lodgedOn: openClaim.lodgedOn)
        }

        let claim = WarrantyClaim(
            lodgedOn: today,
            faultDescription: faultDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .lodged
        )
        do {
            try await repository.addClaim(claim, toWarrantyWithID: warrantyID)
        } catch {
            throw LodgeWarrantyClaimError.couldNotSave
        }
        // An open claim takes the warranty off Expiring Soon, and off the widget.
        await snapshotPublisher.publishLatestSnapshot()
        return claim
    }
}
