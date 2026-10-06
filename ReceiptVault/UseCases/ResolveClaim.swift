import Foundation

enum ResolveClaimError: LocalizedError, Equatable {
    case claimNotFound
    case claimAlreadyClosed(status: ClaimStatus)
    case couldNotSave

    var errorDescription: String? {
        switch self {
        case .claimNotFound:
            "We couldn't find this claim."
        case let .claimAlreadyClosed(status):
            "This claim has already been \(status.displayName.lowercased())."
        case .couldNotSave:
            "The claim couldn't be updated."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .claimNotFound:
            "It may have been removed along with its purchase. Go back to My Purchases and try again."
        case .claimAlreadyClosed:
            "Only lodged or in-progress claims can be resolved or rejected. If the fault has come back, lodge a new claim."
        case .couldNotSave:
            "Please try again in a moment."
        }
    }
}

/// Closes an open claim as resolved or rejected.
struct ResolveClaim: Sendable {
    enum Outcome: String, CaseIterable, Hashable, Sendable {
        case resolved
        case rejected

        var status: ClaimStatus {
            switch self {
            case .resolved: .resolved
            case .rejected: .rejected
            }
        }
    }

    let repository: any PurchaseRepository
    let snapshotPublisher: any WarrantySnapshotPublisher

    @discardableResult
    func execute(claimID: UUID, outcome: Outcome) async throws -> WarrantyClaim {
        let found: WarrantyClaim?
        do {
            found = try await repository.fetchClaim(id: claimID)
        } catch {
            throw ResolveClaimError.couldNotSave
        }
        guard var claim = found else {
            throw ResolveClaimError.claimNotFound
        }
        guard claim.isOpen else {
            throw ResolveClaimError.claimAlreadyClosed(status: claim.status)
        }

        claim.status = outcome.status
        do {
            try await repository.updateClaim(claim)
        } catch {
            throw ResolveClaimError.couldNotSave
        }
        // A closed claim can put the warranty back on Expiring Soon, and on the widget.
        await snapshotPublisher.publishLatestSnapshot()
        return claim
    }
}
