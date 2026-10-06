import Foundation
@testable import ReceiptVault

/// In-memory ReceiptInboxRepository for tests. Records removals and can be told to fail.
actor MockReceiptInbox: ReceiptInboxRepository {
    private(set) var receipts: [UnfiledReceipt]
    private(set) var removedReceiptIDs: [UUID] = []
    private(set) var discardedReceiptIDs: [UUID] = []

    private var readError: Error?
    private var removeError: Error?

    init(receipts: [UnfiledReceipt] = []) {
        self.receipts = receipts
    }

    func failReads(with error: Error = MockStorageError.unavailable) {
        readError = error
    }

    func failRemovals(with error: Error = MockStorageError.unavailable) {
        removeError = error
    }

    func fetchUnfiledReceipts() throws -> [UnfiledReceipt] {
        if let readError { throw readError }
        return receipts
    }

    func add(_ receipt: UnfiledReceipt) {
        receipts.append(receipt)
    }

    func remove(receiptWithID id: UUID) throws {
        if let removeError { throw removeError }
        removedReceiptIDs.append(id)
        receipts.removeAll { $0.id == id }
    }

    func discard(receiptWithID id: UUID) throws {
        if let removeError { throw removeError }
        discardedReceiptIDs.append(id)
        receipts.removeAll { $0.id == id }
    }
}
