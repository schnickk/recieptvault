import XCTest
@testable import ReceiptVault

/// Exercises the real inbox.json reading and writing against a temporary folder in place of the App Group.
final class AppGroupReceiptInboxTests: XCTestCase {
    private var appGroup: TemporaryAppGroup!

    override func setUpWithError() throws {
        appGroup = try TemporaryAppGroup()
    }

    override func tearDown() {
        appGroup.delete()
        super.tearDown()
    }

    /// Saves a receipt file the way the Share Extension does, without adding an inbox entry.
    private func sharedReceipt(_ originalFileName: String, receivedAt: Date) throws -> UnfiledReceipt {
        let fileName = try ReceiptInboxStore(container: appGroup.container).saveFile(Data("receipt".utf8), fileExtension: "pdf")
        return UnfiledReceipt(fileName: fileName, originalFileName: originalFileName, receivedAt: receivedAt)
    }

    func test_receiptInbox_startsEmptyBeforeAnythingIsShared() async throws {
        let inbox = AppGroupReceiptInbox(sharedContainer: appGroup.container)

        let receipts = try await inbox.fetchUnfiledReceipts()

        XCTAssertTrue(receipts.isEmpty)
    }

    func test_receiptInbox_listsSharedReceiptsNewestFirst_andKeepsThemAfterRelaunch() async throws {
        let older = try sharedReceipt("JB Hi-Fi receipt.pdf", receivedAt: TestClock.yesterday)
        let newer = try sharedReceipt("Bunnings receipt.pdf", receivedAt: TestClock.today)
        let inbox = AppGroupReceiptInbox(sharedContainer: appGroup.container)

        try await inbox.add(older)
        try await inbox.add(newer)

        let afterRelaunch = AppGroupReceiptInbox(sharedContainer: appGroup.container)
        let receipts = try await afterRelaunch.fetchUnfiledReceipts()
        XCTAssertEqual(receipts, [newer, older])
    }

    func test_receiptInbox_filingRemovesTheEntryButKeepsTheReceiptForThePurchase() async throws {
        let receipt = try sharedReceipt("JB Hi-Fi receipt.pdf", receivedAt: TestClock.today)
        let inbox = AppGroupReceiptInbox(sharedContainer: appGroup.container)
        try await inbox.add(receipt)

        try await inbox.remove(receiptWithID: receipt.id)

        let receipts = try await inbox.fetchUnfiledReceipts()
        XCTAssertTrue(receipts.isEmpty)
        XCTAssertTrue(appGroup.fileExists(named: receipt.fileName), "The filed purchase still needs this file")
    }

    func test_receiptInbox_discardingRemovesTheEntryAndDeletesTheReceipt() async throws {
        let receipt = try sharedReceipt("Wrong photo.pdf", receivedAt: TestClock.today)
        let inbox = AppGroupReceiptInbox(sharedContainer: appGroup.container)
        try await inbox.add(receipt)

        try await inbox.discard(receiptWithID: receipt.id)

        let receipts = try await inbox.fetchUnfiledReceipts()
        XCTAssertTrue(receipts.isEmpty)
        XCTAssertFalse(appGroup.fileExists(named: receipt.fileName))
    }

    func test_receiptInbox_explainsUnavailableAppGroupInsteadOfCrashing() async {
        let inbox = AppGroupReceiptInbox(sharedContainer: nil)

        await assertThrows(SharedContainerError.appGroupUnavailable) {
            try await inbox.fetchUnfiledReceipts()
        }
    }
}
