import XCTest
@testable import ReceiptVault

final class WarrantyRulesTests: XCTestCase {
    private let calendar = TestClock.calendar

    func test_warranty_endingToday_isStillActive() {
        let warranty = Warranty.manufacturer(endingOn: TestClock.startOfDay(2026, 10, 6))
        let lastMinuteOfToday = TestClock.date(2026, 10, 6, hour: 23, minute: 59)

        XCTAssertTrue(warranty.isActive(on: TestClock.today, calendar: calendar))
        XCTAssertTrue(warranty.isActive(on: lastMinuteOfToday, calendar: calendar))
        XCTAssertEqual(warranty.daysRemaining(from: TestClock.today, calendar: calendar), 0)
    }

    func test_warranty_endedYesterday_hasEnded() {
        let warranty = Warranty.manufacturer(endingOn: TestClock.startOfDay(2026, 10, 5))

        XCTAssertTrue(warranty.hasEnded(on: TestClock.today, calendar: calendar))
        XCTAssertEqual(warranty.daysRemaining(from: TestClock.today, calendar: calendar), -1)
    }

    func test_warranty_daysRemaining_countsWholeCalendarDays() {
        let warranty = Warranty.manufacturer(endingOn: TestClock.daysFromToday(30))

        XCTAssertEqual(warranty.daysRemaining(from: TestClock.today, calendar: calendar), 30)
    }

    func test_claim_lodgedAndInProgressCountAsOpen() {
        XCTAssertTrue(WarrantyClaim.claim(.lodged).isOpen)
        XCTAssertTrue(WarrantyClaim.claim(.inProgress).isOpen)
        XCTAssertFalse(WarrantyClaim.claim(.resolved).isOpen)
        XCTAssertFalse(WarrantyClaim.claim(.rejected).isOpen)
    }

    func test_warrantyKind_endedLabel_saysWarrantyEndedNotNotCovered() {
        XCTAssertEqual(WarrantyKind.manufacturer.endedLabel, "Manufacturer warranty ended")
        XCTAssertEqual(WarrantyKind.extended.endedLabel, "Extended warranty ended")
    }

    func test_expiringSoon_listsWarrantiesEndingWithin30DaysWithoutOpenClaim_soonestFirst() {
        let endsToday = Warranty.manufacturer(endingOn: TestClock.daysFromToday(0))
        let endsIn5DaysClaimResolved = Warranty.manufacturer(endingOn: TestClock.daysFromToday(5), claims: [.claim(.resolved)])
        let endsIn10DaysClaimOpen = Warranty.manufacturer(endingOn: TestClock.daysFromToday(10), claims: [.claim(.inProgress)])
        let endsIn30Days = Warranty.manufacturer(endingOn: TestClock.daysFromToday(30))
        let endsIn31Days = Warranty.manufacturer(endingOn: TestClock.daysFromToday(31))
        let endedYesterday = Warranty.manufacturer(endingOn: TestClock.daysFromToday(-1))
        let purchases = [
            Purchase.fridge(warranties: [endsIn30Days, endedYesterday, endsIn10DaysClaimOpen]),
            Purchase.fridge(warranties: [endsIn31Days, endsIn5DaysClaimResolved, endsToday]),
        ]

        let expiring = ExpiringSoon.warranties(in: purchases, today: TestClock.today, calendar: calendar)

        XCTAssertEqual(expiring.map(\.warranty.id), [endsToday.id, endsIn5DaysClaimResolved.id, endsIn30Days.id])
        XCTAssertEqual(expiring.map(\.daysRemaining), [0, 5, 30])
    }
}
