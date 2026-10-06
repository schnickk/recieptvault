import XCTest
@testable import ReceiptVault

final class WarrantyStatusTests: XCTestCase {
    private let calendar = TestClock.calendar

    func test_purchaseStatus_showsActiveWhenMoreThan30DaysRemain() {
        let purchase = Purchase.fridge(warranties: [.manufacturer(endingOn: TestClock.daysFromToday(31))])

        XCTAssertEqual(purchase.warrantyStatus(on: TestClock.today, calendar: calendar), .active(daysRemaining: 31))
        XCTAssertEqual(purchase.warrantyStatus(on: TestClock.today, calendar: calendar).label, "Active")
    }

    func test_purchaseStatus_showsEndingInNDaysWithin30Days() {
        let purchase = Purchase.fridge(warranties: [.manufacturer(endingOn: TestClock.daysFromToday(9))])

        XCTAssertEqual(purchase.warrantyStatus(on: TestClock.today, calendar: calendar).label, "Ending in 9 days")
    }

    func test_purchaseStatus_saysManufacturerWarrantyEnded_neverNotCovered() {
        let purchase = Purchase.fridge(warranties: [.manufacturer(endingOn: TestClock.daysFromToday(-10))])

        let label = purchase.warrantyStatus(on: TestClock.today, calendar: calendar).label

        XCTAssertEqual(label, "Manufacturer warranty ended")
        XCTAssertFalse(label.localizedCaseInsensitiveContains("not covered"))
    }

    func test_purchaseStatus_staysActiveWhileExtendedWarrantyContinues() {
        let ended = Warranty.manufacturer(endingOn: TestClock.daysFromToday(-10))
        let extended = Warranty(kind: .extended, lengthInMonths: 48, expiryDate: TestClock.daysFromToday(400))
        let purchase = Purchase.fridge(warranties: [ended, extended])

        XCTAssertEqual(purchase.warrantyStatus(on: TestClock.today, calendar: calendar), .active(daysRemaining: 400))
    }

    func test_warrantyStatus_endingToday_saysEndsToday() {
        let warranty = Warranty.manufacturer(endingOn: TestClock.daysFromToday(0))

        XCTAssertEqual(warranty.status(on: TestClock.today, calendar: calendar).label, "Ends today")
    }
}
