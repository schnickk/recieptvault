import Foundation

/// Inbox kept in memory, for SwiftUI previews and the unit-test host.
actor InMemoryReceiptInbox: ReceiptInboxRepository {
    private var receipts: [UnfiledReceipt]

    init(receipts: [UnfiledReceipt] = []) {
        self.receipts = receipts
    }

    func fetchUnfiledReceipts() -> [UnfiledReceipt] {
        receipts.sorted { $0.receivedAt > $1.receivedAt }
    }

    func add(_ receipt: UnfiledReceipt) {
        receipts.removeAll { $0.id == receipt.id }
        receipts.append(receipt)
    }

    func remove(receiptWithID id: UUID) {
        receipts.removeAll { $0.id == id }
    }

    func discard(receiptWithID id: UUID) {
        receipts.removeAll { $0.id == id }
    }
}
