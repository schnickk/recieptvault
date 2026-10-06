import XCTest
@testable import ReceiptVault

/// Writes the widget snapshot into a temporary folder in place of the App Group and checks what the widget would read.
final class AppGroupWarrantySnapshotPublisherTests: XCTestCase {
    private var appGroup: TemporaryAppGroup!
    private let reloads = WidgetReloadCounter()

    override func setUpWithError() throws {
        appGroup = try TemporaryAppGroup()
    }

    override func tearDown() {
        appGroup.delete()
        super.tearDown()
    }

    private func makePublisher(purchases: [Purchase], sharedContainer: SharedContainer?) -> AppGroupWarrantySnapshotPublisher {
        let reloads = reloads
        return AppGroupWarrantySnapshotPublisher(
            repository: MockPurchaseRepository(purchases: purchases),
            sharedContainer: sharedContainer,
            now: TestClock.now,
            calendar: TestClock.calendar,
            reloadWidgets: { reloads.record() }
        )
    }

    private func purchase(_ itemName: String, endingInDays days: Int, claims: [WarrantyClaim] = []) -> Purchase {
        Purchase(
            itemName: itemName,
            retailer: "Harvey Norman",
            purchaseDate: TestClock.date(2025, 1, 10),
            price: 499,
            category: .appliances,
            warranties: [.manufacturer(endingOn: TestClock.daysFromToday(days), claims: claims)]
        )
    }

    func test_widgetSnapshot_holdsAtMostFiveWarranties_soonestFirst_leavingOutOpenClaims() async throws {
        let purchases = [
            purchase("Toaster", endingInDays: 6),
            purchase("Fridge with open claim", endingInDays: 1, claims: [.claim(.inProgress)]),
            purchase("Kettle", endingInDays: 2),
            purchase("Blender", endingInDays: 7),
            purchase("Microwave", endingInDays: 3),
            purchase("Dishwasher", endingInDays: 4),
            purchase("Air fryer", endingInDays: 5),
            purchase("Television", endingInDays: 45),
        ]

        await makePublisher(purchases: purchases, sharedContainer: appGroup.container).publishLatestSnapshot()

        let snapshot = try XCTUnwrap(WarrantySnapshotFile.read(from: appGroup.container))
        XCTAssertEqual(snapshot.items.map(\.itemName), ["Kettle", "Microwave", "Dishwasher", "Air fryer", "Toaster"])
        XCTAssertEqual(snapshot.generatedAt, TestClock.today)
        XCTAssertEqual(reloads.count, 1, "The widget is asked to redraw after writing")
    }

    func test_widgetSnapshot_showsEmptyStateWhenNothingEndsInTheNext30Days() async throws {
        await makePublisher(purchases: [purchase("Television", endingInDays: 45)], sharedContainer: appGroup.container)
            .publishLatestSnapshot()

        let snapshot = try XCTUnwrap(WarrantySnapshotFile.read(from: appGroup.container))
        XCTAssertTrue(snapshot.items.isEmpty)
    }

    func test_widgetSnapshot_isSkippedQuietlyWhenAppGroupIsUnavailable() async {
        await makePublisher(purchases: [purchase("Kettle", endingInDays: 2)], sharedContainer: nil).publishLatestSnapshot()

        XCTAssertEqual(reloads.count, 0)
        XCTAssertNil(WarrantySnapshotFile.read(from: appGroup.container))
    }
}
