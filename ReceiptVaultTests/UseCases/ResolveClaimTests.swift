import XCTest
@testable import ReceiptVault

final class ResolveClaimTests: XCTestCase {
    private let publisher = MockWarrantySnapshotPublisher()

    private func makeResolveClaim(claim: WarrantyClaim) -> (ResolveClaim, MockPurchaseRepository) {
        let warranty = Warranty.manufacturer(endingOn: TestClock.date(2027, 3, 14), claims: [claim])
        let repository = MockPurchaseRepository(purchases: [.fridge(warranties: [warranty])])
        return (ResolveClaim(repository: repository, snapshotPublisher: publisher), repository)
    }

    // MARK: Happy paths

    func test_resolveClaim_resolvesLodgedClaim() async throws {
        let claim = WarrantyClaim.claim(.lodged)
        let (resolveClaim, repository) = makeResolveClaim(claim: claim)

        let resolved = try await resolveClaim.execute(claimID: claim.id, outcome: .resolved)

        XCTAssertEqual(resolved.status, .resolved)
        XCTAssertFalse(resolved.isOpen)
        let updated = await repository.updatedClaims
        XCTAssertEqual(updated, [resolved])
        let publishCount = await publisher.publishCount
        XCTAssertEqual(publishCount, 1, "A closed claim can put the warranty back on the widget")
    }

    func test_resolveClaim_rejectsClaimThatIsInProgress() async throws {
        let claim = WarrantyClaim.claim(.inProgress)
        let (resolveClaim, _) = makeResolveClaim(claim: claim)

        let rejected = try await resolveClaim.execute(claimID: claim.id, outcome: .rejected)

        XCTAssertEqual(rejected.status, .rejected)
    }

    // MARK: Rules

    func test_resolveClaim_refusesClaimAlreadyResolved() async {
        let claim = WarrantyClaim.claim(.resolved)
        let (resolveClaim, repository) = makeResolveClaim(claim: claim)

        await assertThrows(ResolveClaimError.claimAlreadyClosed(status: .resolved)) {
            try await resolveClaim.execute(claimID: claim.id, outcome: .rejected)
        }
        let updated = await repository.updatedClaims
        XCTAssertTrue(updated.isEmpty)
    }

    func test_resolveClaim_refusesClaimAlreadyRejected() async {
        let claim = WarrantyClaim.claim(.rejected)
        let (resolveClaim, _) = makeResolveClaim(claim: claim)

        await assertThrows(ResolveClaimError.claimAlreadyClosed(status: .rejected)) {
            try await resolveClaim.execute(claimID: claim.id, outcome: .resolved)
        }
    }

    func test_resolveClaim_refusesClaimThatNoLongerExists() async {
        let (resolveClaim, _) = makeResolveClaim(claim: .claim(.lodged))

        await assertThrows(ResolveClaimError.claimNotFound) {
            try await resolveClaim.execute(claimID: UUID(), outcome: .resolved)
        }
    }

    // MARK: Storage

    func test_resolveClaim_reportsCouldNotSaveWhenStorageFails() async {
        let claim = WarrantyClaim.claim(.lodged)
        let (resolveClaim, repository) = makeResolveClaim(claim: claim)
        await repository.failWrites()

        await assertThrows(ResolveClaimError.couldNotSave) {
            try await resolveClaim.execute(claimID: claim.id, outcome: .resolved)
        }
    }
}
