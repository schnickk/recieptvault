import XCTest
@testable import ReceiptVault

final class WarrantySnapshotTests: XCTestCase {
    private let calendar = TestClock.calendar

    private func expiring(_ name: String, endingInDays days: Int) -> ExpiringWarranty {
        let warranty = Warranty.manufacturer(endingOn: TestClock.daysFromToday(days))
        return ExpiringWarranty(purchaseID: UUID(), itemName: name, retailer: "Harvey Norman", warranty: warranty, daysRemaining: days)
    }

    func test_snapshot_keepsOnlyTheFiveSoonestWarranties() {
        let expiringList = (1...7).map { expiring("Item \($0)", endingInDays: $0) }

        let snapshot = WarrantySnapshot(expiring: expiringList, generatedAt: TestClock.today)

        XCTAssertEqual(snapshot.items.map(\.itemName), ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"])
        XCTAssertEqual(snapshot.items.first?.retailer, "Harvey Norman")
        XCTAssertEqual(snapshot.items.first?.warrantyKind, .manufacturer)
    }

    func test_snapshot_countsDaysLeftOnTheDayItIsDrawn_notTheDayItWasSaved() {
        let snapshot = WarrantySnapshot(expiring: [expiring("Dishwasher", endingInDays: 9)], generatedAt: TestClock.today)
        let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: TestClock.today)!

        XCTAssertEqual(snapshot.itemsEndingSoon(on: TestClock.today, calendar: calendar).first?.daysLeft, 9)
        XCTAssertEqual(snapshot.itemsEndingSoon(on: threeDaysLater, calendar: calendar).first?.daysLeft, 6)
    }

    func test_snapshot_dropsWarrantyTheDayAfterItEnds() {
        let snapshot = WarrantySnapshot(expiring: [expiring("Dishwasher", endingInDays: 0)], generatedAt: TestClock.today)

        XCTAssertEqual(snapshot.itemsEndingSoon(on: TestClock.today, calendar: calendar).count, 1)
        XCTAssertTrue(snapshot.itemsEndingSoon(on: TestClock.tomorrow, calendar: calendar).isEmpty)
    }

    func test_snapshot_daysLeftLabels() {
        XCTAssertEqual(WarrantySnapshot.Item.daysLeftLabel(0), "Ends today")
        XCTAssertEqual(WarrantySnapshot.Item.daysLeftLabel(1), "1 day left")
        XCTAssertEqual(WarrantySnapshot.Item.daysLeftLabel(9), "9 days left")
    }

    func test_appLink_expiringSoonRoundTrips() {
        XCTAssertEqual(AppLink.expiringSoon.url.absoluteString, "receiptvault://expiring")
        XCTAssertEqual(AppLink(url: URL(string: "receiptvault://expiring")!), .expiringSoon)
        XCTAssertNil(AppLink(url: URL(string: "https://example.com/expiring")!))
    }
}
