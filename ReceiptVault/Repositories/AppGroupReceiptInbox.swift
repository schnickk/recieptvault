import Foundation

/// ReceiptInboxRepository backed by inbox.json in the App Group, the same file the Share Extension writes to.
struct AppGroupReceiptInbox: ReceiptInboxRepository {
    private let store: Result<ReceiptInboxStore, SharedContainerError>

    /// If the App Group can't be opened, every call throws SharedContainerError.appGroupUnavailable
    /// instead of crashing the app.
    init(sharedContainer: SharedContainer?) {
        store = sharedContainer.map { .success(ReceiptInboxStore(container: $0)) } ?? .failure(.appGroupUnavailable)
    }

    func fetchUnfiledReceipts() async throws -> [UnfiledReceipt] {
        try store.get().loadReceipts().sorted { $0.receivedAt > $1.receivedAt }
    }

    func add(_ receipt: UnfiledReceipt) async throws {
        try store.get().add(receipt)
    }

    func remove(receiptWithID id: UUID) async throws {
        try store.get().removeEntry(id: id)
    }

    func discard(receiptWithID id: UUID) async throws {
        try store.get().discard(id: id)
    }
}
