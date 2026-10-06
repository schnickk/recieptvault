import XCTest
@testable import ReceiptVault

final class RecordPurchaseTests: XCTestCase {
    private let publisher = MockWarrantySnapshotPublisher()

    private func makeRecordPurchase() -> (RecordPurchase, MockPurchaseRepository) {
        let repository = MockPurchaseRepository()
        let recordPurchase = RecordPurchase(
            repository: repository, snapshotPublisher: publisher, now: TestClock.now, calendar: TestClock.calendar
        )
        return (recordPurchase, repository)
    }

    // MARK: Happy path

    func test_recordPurchase_savesPurchaseWithWarrantyEndingTwelveMonthsLater() async throws {
        let (recordPurchase, repository) = makeRecordPurchase()

        let purchase = try await recordPurchase.execute(.headphones())

        XCTAssertEqual(purchase.itemName, "Noise-cancelling headphones")
        XCTAssertEqual(purchase.warranties.first?.expiryDate, TestClock.startOfDay(2027, 10, 6))
        let saved = await repository.savedPurchases
        XCTAssertEqual(saved, [purchase])
    }

    // MARK: Purchase date

    func test_recordPurchase_acceptsPurchaseDatedToday() async throws {
        let (recordPurchase, repository) = makeRecordPurchase()
        let laterToday = TestClock.date(2026, 10, 6, hour: 23, minute: 59)

        try await recordPurchase.execute(.headphones(purchasedOn: laterToday))

        let saved = await repository.savedPurchases
        XCTAssertEqual(saved.count, 1)
    }

    func test_recordPurchase_rejectsPurchaseDatedTomorrow() async {
        let (recordPurchase, repository) = makeRecordPurchase()

        await assertThrows(RecordPurchaseError.purchaseDateInFuture) {
            try await recordPurchase.execute(.headphones(purchasedOn: TestClock.tomorrow))
        }
        let saved = await repository.savedPurchases
        XCTAssertTrue(saved.isEmpty)
    }

    // MARK: Price

    func test_recordPurchase_acceptsPriceOfOneCent() async throws {
        let (recordPurchase, _) = makeRecordPurchase()

        let purchase = try await recordPurchase.execute(.headphones(price: Decimal(string: "0.01")!))

        XCTAssertEqual(purchase.price, Decimal(string: "0.01")!)
    }

    func test_recordPurchase_rejectsPriceOfZeroDollars() async {
        let (recordPurchase, repository) = makeRecordPurchase()

        await assertThrows(RecordPurchaseError.priceNotAboveZero) {
            try await recordPurchase.execute(.headphones(price: 0))
        }
        let saved = await repository.savedPurchases
        XCTAssertTrue(saved.isEmpty)
    }

    func test_recordPurchase_rejectsNegativePrice() async {
        let (recordPurchase, _) = makeRecordPurchase()

        await assertThrows(RecordPurchaseError.priceNotAboveZero) {
            try await recordPurchase.execute(.headphones(price: -20))
        }
    }

    // MARK: Warranty length

    func test_recordPurchase_acceptsWarrantyOfZeroMonths_endingOnPurchaseDay() async throws {
        let (recordPurchase, _) = makeRecordPurchase()

        let purchase = try await recordPurchase.execute(.headphones(warranties: [.init(kind: .manufacturer, lengthInMonths: 0)]))

        let warranty = try XCTUnwrap(purchase.warranties.first)
        XCTAssertEqual(warranty.expiryDate, TestClock.startOfDay(2026, 10, 6))
        XCTAssertTrue(warranty.isActive(on: TestClock.today, calendar: TestClock.calendar))
    }

    func test_recordPurchase_acceptsWarrantyOf120Months_endingTenYearsLater() async throws {
        let (recordPurchase, _) = makeRecordPurchase()

        let purchase = try await recordPurchase.execute(.headphones(warranties: [.init(kind: .extended, lengthInMonths: 120)]))

        XCTAssertEqual(purchase.warranties.first?.expiryDate, TestClock.startOfDay(2036, 10, 6))
    }

    func test_recordPurchase_rejectsWarrantyOf121Months() async {
        let (recordPurchase, repository) = makeRecordPurchase()
        let warranties: [RecordPurchase.WarrantyTerms] = [
            .init(kind: .manufacturer, lengthInMonths: 12),
            .init(kind: .extended, lengthInMonths: 121),
        ]

        await assertThrows(RecordPurchaseError.warrantyLengthOutOfRange(kind: .extended, months: 121)) {
            try await recordPurchase.execute(.headphones(warranties: warranties))
        }
        let saved = await repository.savedPurchases
        XCTAssertTrue(saved.isEmpty, "One bad warranty stops the whole purchase being saved")
    }

    func test_recordPurchase_rejectsNegativeWarrantyLength() async {
        let (recordPurchase, _) = makeRecordPurchase()

        await assertThrows(RecordPurchaseError.warrantyLengthOutOfRange(kind: .manufacturer, months: -1)) {
            try await recordPurchase.execute(.headphones(warranties: [.init(kind: .manufacturer, lengthInMonths: -1)]))
        }
    }

    // MARK: Widget

    func test_recordPurchase_refreshesWidgetAfterSaving() async throws {
        let (recordPurchase, _) = makeRecordPurchase()

        try await recordPurchase.execute(.headphones())

        let publishCount = await publisher.publishCount
        XCTAssertEqual(publishCount, 1)
    }

    func test_recordPurchase_leavesWidgetAloneWhenPurchaseIsRejected() async {
        let (recordPurchase, _) = makeRecordPurchase()

        await assertThrows(RecordPurchaseError.priceNotAboveZero) {
            try await recordPurchase.execute(.headphones(price: 0))
        }
        let publishCount = await publisher.publishCount
        XCTAssertEqual(publishCount, 0)
    }

    // MARK: Storage

    func test_recordPurchase_reportsCouldNotSaveWhenStorageFails() async {
        let (recordPurchase, repository) = makeRecordPurchase()
        await repository.failWrites()

        await assertThrows(RecordPurchaseError.couldNotSave) {
            try await recordPurchase.execute(.headphones())
        }
    }
}
