import XCTest
@testable import ReceiptVault

final class LodgeWarrantyClaimTests: XCTestCase {
    private let publisher = MockWarrantySnapshotPublisher()

    private func makeLodgeWarrantyClaim(warranty: Warranty) -> (LodgeWarrantyClaim, MockPurchaseRepository) {
        let repository = MockPurchaseRepository(purchases: [.fridge(warranties: [warranty])])
        let lodgeWarrantyClaim = LodgeWarrantyClaim(
            repository: repository, snapshotPublisher: publisher, now: TestClock.now, calendar: TestClock.calendar
        )
        return (lodgeWarrantyClaim, repository)
    }

    // MARK: Happy paths

    func test_lodgeWarrantyClaim_lodgesClaimOnActiveWarranty() async throws {
        let warranty = Warranty.manufacturer(endingOn: TestClock.date(2027, 3, 14))
        let (lodgeWarrantyClaim, repository) = makeLodgeWarrantyClaim(warranty: warranty)

        let claim = try await lodgeWarrantyClaim.execute(warrantyID: warranty.id, faultDescription: "  Stopped cooling  ")

        XCTAssertEqual(claim.status, .lodged)
        XCTAssertEqual(claim.lodgedOn, TestClock.today)
        XCTAssertEqual(claim.faultDescription, "Stopped cooling")
        let added = await repository.addedClaims
        XCTAssertEqual(added.map(\.claim), [claim])
        XCTAssertEqual(added.map(\.warrantyID), [warranty.id])
        let publishCount = await publisher.publishCount
        XCTAssertEqual(publishCount, 1, "An open claim takes the warranty off the widget")
    }

    func test_lodgeWarrantyClaim_acceptsWarrantyEndingToday() async throws {
        let warranty = Warranty.manufacturer(endingOn: TestClock.startOfDay(2026, 10, 6))
        let (lodgeWarrantyClaim, _) = makeLodgeWarrantyClaim(warranty: warranty)

        let claim = try await lodgeWarrantyClaim.execute(warrantyID: warranty.id, faultDescription: "Stopped cooling")

        XCTAssertTrue(claim.isOpen)
    }

    func test_lodgeWarrantyClaim_allowsNewClaimOnceEarlierClaimsAreClosed() async throws {
        let warranty = Warranty.manufacturer(endingOn: TestClock.date(2027, 3, 14), claims: [.claim(.resolved), .claim(.rejected)])
        let (lodgeWarrantyClaim, repository) = makeLodgeWarrantyClaim(warranty: warranty)

        try await lodgeWarrantyClaim.execute(warrantyID: warranty.id, faultDescription: "Fault has come back")

        let added = await repository.addedClaims
        XCTAssertEqual(added.count, 1)
    }

    // MARK: Rules

    func test_lodgeWarrantyClaim_rejectsWarrantyThatEndedYesterday_pointingToConsumerLaw() async {
        let endedOn = TestClock.startOfDay(2026, 10, 5)
        let warranty = Warranty.manufacturer(endingOn: endedOn)
        let (lodgeWarrantyClaim, repository) = makeLodgeWarrantyClaim(warranty: warranty)

        await assertThrows(LodgeWarrantyClaimError.warrantyEnded(endedOn: endedOn)) {
            try await lodgeWarrantyClaim.execute(warrantyID: warranty.id, faultDescription: "Stopped cooling")
        }
        XCTAssertEqual(
            LodgeWarrantyClaimError.warrantyEnded(endedOn: endedOn).errorDescription,
            "This warranty ended on 5 October 2026. You may still be covered under the Australian Consumer Law. Contact the retailer directly."
        )
        let added = await repository.addedClaims
        XCTAssertTrue(added.isEmpty)
        let publishCount = await publisher.publishCount
        XCTAssertEqual(publishCount, 0)
    }

    func test_lodgeWarrantyClaim_rejectsSecondClaimWhileOneIsLodged() async {
        let openClaim = WarrantyClaim.claim(.lodged)
        let warranty = Warranty.manufacturer(endingOn: TestClock.date(2027, 3, 14), claims: [openClaim])
        let (lodgeWarrantyClaim, _) = makeLodgeWarrantyClaim(warranty: warranty)

        await assertThrows(LodgeWarrantyClaimError.openClaimAlreadyExists(lodgedOn: openClaim.lodgedOn)) {
            try await lodgeWarrantyClaim.execute(warrantyID: warranty.id, faultDescription: "Another fault")
        }
    }

    func test_lodgeWarrantyClaim_rejectsSecondClaimWhileOneIsInProgress() async {
        let openClaim = WarrantyClaim.claim(.inProgress)
        let warranty = Warranty.manufacturer(endingOn: TestClock.date(2027, 3, 14), claims: [openClaim])
        let (lodgeWarrantyClaim, _) = makeLodgeWarrantyClaim(warranty: warranty)

        await assertThrows(LodgeWarrantyClaimError.openClaimAlreadyExists(lodgedOn: openClaim.lodgedOn)) {
            try await lodgeWarrantyClaim.execute(warrantyID: warranty.id, faultDescription: "Another fault")
        }
    }

    func test_lodgeWarrantyClaim_rejectsWarrantyThatNoLongerExists() async {
        let (lodgeWarrantyClaim, _) = makeLodgeWarrantyClaim(warranty: .manufacturer(endingOn: TestClock.date(2027, 3, 14)))

        await assertThrows(LodgeWarrantyClaimError.warrantyNotFound) {
            try await lodgeWarrantyClaim.execute(warrantyID: UUID(), faultDescription: "Stopped cooling")
        }
    }

    // MARK: Storage

    func test_lodgeWarrantyClaim_reportsCouldNotSaveWhenStorageFails() async {
        let warranty = Warranty.manufacturer(endingOn: TestClock.date(2027, 3, 14))
        let (lodgeWarrantyClaim, repository) = makeLodgeWarrantyClaim(warranty: warranty)
        await repository.failWrites()

        await assertThrows(LodgeWarrantyClaimError.couldNotSave) {
            try await lodgeWarrantyClaim.execute(warrantyID: warranty.id, faultDescription: "Stopped cooling")
        }
    }
}
