import XCTest
@testable import ReceiptVault

final class FileSharedReceiptTests: XCTestCase {
    private let receipt = UnfiledReceipt.sharedPDF()
    private let publisher = MockWarrantySnapshotPublisher()

    private func makeFileSharedReceipt(
        purchases: [Purchase] = [],
        receipts: [UnfiledReceipt]? = nil
    ) -> (FileSharedReceipt, MockPurchaseRepository, MockReceiptInbox) {
        let repository = MockPurchaseRepository(purchases: purchases)
        let inbox = MockReceiptInbox(receipts: receipts ?? [receipt])
        let useCase = FileSharedReceipt(
            purchases: repository, inbox: inbox, snapshotPublisher: publisher, now: TestClock.now, calendar: TestClock.calendar
        )
        return (useCase, repository, inbox)
    }

    // MARK: Happy paths

    func test_fileSharedReceipt_createsNewPurchaseHoldingReceiptAndClearsInbox() async throws {
        let (fileSharedReceipt, repository, inbox) = makeFileSharedReceipt()

        let purchase = try await fileSharedReceipt.execute(receiptID: receipt.id, into: .newPurchase(.headphones()))

        XCTAssertEqual(purchase.receiptFileName, receipt.fileName)
        XCTAssertEqual(purchase.warranties.first?.expiryDate, TestClock.startOfDay(2027, 10, 6))
        let saved = await repository.savedPurchases
        let removed = await inbox.removedReceiptIDs
        XCTAssertEqual(saved, [purchase])
        XCTAssertEqual(removed, [receipt.id])
        let publishCount = await publisher.publishCount
        XCTAssertEqual(publishCount, 1, "Filing refreshes the widget")
    }

    func test_fileSharedReceipt_attachesReceiptToExistingPurchaseWithoutOne() async throws {
        let fridge = Purchase.fridge()
        let (fileSharedReceipt, repository, inbox) = makeFileSharedReceipt(purchases: [fridge])

        let purchase = try await fileSharedReceipt.execute(receiptID: receipt.id, into: .existingPurchase(id: fridge.id))

        XCTAssertEqual(purchase.id, fridge.id)
        XCTAssertEqual(purchase.receiptFileName, receipt.fileName)
        let stored = await repository.purchases
        let remaining = await inbox.receipts
        XCTAssertEqual(stored.first?.receiptFileName, receipt.fileName)
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: Rules

    func test_fileSharedReceipt_rejectsReceiptNoLongerInInbox() async {
        let (fileSharedReceipt, repository, _) = makeFileSharedReceipt(receipts: [])

        await assertThrows(FileSharedReceiptError.receiptNoLongerInInbox) {
            try await fileSharedReceipt.execute(receiptID: self.receipt.id, into: .newPurchase(.headphones()))
        }
        let saved = await repository.savedPurchases
        XCTAssertTrue(saved.isEmpty)
    }

    func test_fileSharedReceipt_rejectsFilingSameReceiptTwice_becauseItIsNoLongerInInbox() async throws {
        let (fileSharedReceipt, repository, _) = makeFileSharedReceipt()
        try await fileSharedReceipt.execute(receiptID: receipt.id, into: .newPurchase(.headphones()))

        await assertThrows(FileSharedReceiptError.receiptNoLongerInInbox) {
            try await fileSharedReceipt.execute(receiptID: self.receipt.id, into: .newPurchase(.headphones()))
        }
        let saved = await repository.savedPurchases
        XCTAssertEqual(saved.count, 1, "No duplicate purchase is created")
        XCTAssertEqual(
            FileSharedReceiptError.receiptNoLongerInInbox.errorDescription,
            "This receipt is no longer in Unfiled Receipts."
        )
    }

    func test_fileSharedReceipt_keepsReceiptFileByRemovingOnlyTheInboxEntry() async throws {
        let (fileSharedReceipt, _, inbox) = makeFileSharedReceipt()

        let purchase = try await fileSharedReceipt.execute(receiptID: receipt.id, into: .newPurchase(.headphones()))

        let removed = await inbox.removedReceiptIDs
        let discarded = await inbox.discardedReceiptIDs
        XCTAssertEqual(removed, [receipt.id])
        XCTAssertTrue(discarded.isEmpty, "Filing must not delete the file the purchase now points at")
        XCTAssertEqual(purchase.receiptFileName, receipt.fileName)
    }

    func test_fileSharedReceipt_rejectsPurchaseThatAlreadyHasReceipt() async {
        let fridge = Purchase.fridge(receiptFileName: "earlier-receipt.jpg")
        let (fileSharedReceipt, repository, inbox) = makeFileSharedReceipt(purchases: [fridge])

        await assertThrows(FileSharedReceiptError.purchaseAlreadyHasReceipt(itemName: "Fridge")) {
            try await fileSharedReceipt.execute(receiptID: self.receipt.id, into: .existingPurchase(id: fridge.id))
        }
        let saved = await repository.savedPurchases
        let remaining = await inbox.receipts
        XCTAssertTrue(saved.isEmpty)
        XCTAssertEqual(remaining, [receipt], "The receipt stays in the inbox to be filed elsewhere")
    }

    func test_fileSharedReceipt_rejectsPurchaseThatNoLongerExists() async {
        let (fileSharedReceipt, _, _) = makeFileSharedReceipt()

        await assertThrows(FileSharedReceiptError.purchaseNotFound) {
            try await fileSharedReceipt.execute(receiptID: self.receipt.id, into: .existingPurchase(id: UUID()))
        }
    }

    func test_fileSharedReceipt_appliesRecordPurchaseRules_rejectingPurchaseDatedTomorrow() async {
        let (fileSharedReceipt, _, inbox) = makeFileSharedReceipt()

        await assertThrows(FileSharedReceiptError.purchaseDetailsInvalid(.purchaseDateInFuture)) {
            try await fileSharedReceipt.execute(receiptID: self.receipt.id, into: .newPurchase(.headphones(purchasedOn: TestClock.tomorrow)))
        }
        let remaining = await inbox.receipts
        XCTAssertEqual(remaining, [receipt])
    }

    // MARK: Storage

    func test_fileSharedReceipt_keepsReceiptInInboxWhenSaveFails() async {
        let (fileSharedReceipt, repository, inbox) = makeFileSharedReceipt()
        await repository.failWrites()

        await assertThrows(FileSharedReceiptError.couldNotFile) {
            try await fileSharedReceipt.execute(receiptID: self.receipt.id, into: .newPurchase(.headphones()))
        }
        let removed = await inbox.removedReceiptIDs
        XCTAssertTrue(removed.isEmpty)
    }

    func test_fileSharedReceipt_reportsCouldNotFileWhenInboxCannotBeRead() async {
        let (fileSharedReceipt, _, inbox) = makeFileSharedReceipt()
        await inbox.failReads()

        await assertThrows(FileSharedReceiptError.couldNotFile) {
            try await fileSharedReceipt.execute(receiptID: self.receipt.id, into: .newPurchase(.headphones()))
        }
    }

    func test_fileSharedReceipt_reportsReceiptStillInInboxWhenRemovalFails() async {
        let (fileSharedReceipt, repository, inbox) = makeFileSharedReceipt()
        await inbox.failRemovals()

        await assertThrows(FileSharedReceiptError.filedButStillInInbox) {
            try await fileSharedReceipt.execute(receiptID: self.receipt.id, into: .newPurchase(.headphones()))
        }
        let saved = await repository.savedPurchases
        XCTAssertEqual(saved.count, 1, "The purchase was still saved")
    }
}
