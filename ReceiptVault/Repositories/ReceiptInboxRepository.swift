import Foundation

/// The list of receipts shared into Receipt Vault that are waiting to be filed.
protocol ReceiptInboxRepository: Sendable {
    /// Newest first.
    func fetchUnfiledReceipts() async throws -> [UnfiledReceipt]
    func add(_ receipt: UnfiledReceipt) async throws
    /// Removes the entry once the receipt is filed. The file is kept, because the purchase now points at it.
    func remove(receiptWithID id: UUID) async throws
    /// Removes the entry and deletes the file. Used when the shopper discards a receipt they don't need.
    func discard(receiptWithID id: UUID) async throws
}
