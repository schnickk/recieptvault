import Foundation

/// A receipt shared into Receipt Vault that hasn't been filed against a purchase yet.
/// Lives in the App Group's inbox.json, not in Core Data, so the Share Extension can write it.
struct UnfiledReceipt: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    /// Name of the copy saved in the App Group container.
    var fileName: String
    /// Name of the file as the shopper shared it, e.g. "JB Hi-Fi receipt.pdf".
    var originalFileName: String
    var receivedAt: Date

    init(id: UUID = UUID(), fileName: String, originalFileName: String, receivedAt: Date) {
        self.id = id
        self.fileName = fileName
        self.originalFileName = originalFileName
        self.receivedAt = receivedAt
    }
}
