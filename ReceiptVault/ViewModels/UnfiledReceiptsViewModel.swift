import Foundation
import Observation

/// Receipts shared into Receipt Vault that are waiting to be filed. Also drives the tab badge.
@MainActor
@Observable
final class UnfiledReceiptsViewModel {
    private(set) var receipts: [UnfiledReceipt] = []
    private(set) var hasLoaded = false
    var alert: ShopperAlert?

    private let inbox: any ReceiptInboxRepository

    init(inbox: any ReceiptInboxRepository) {
        self.inbox = inbox
    }

    var badgeCount: Int { receipts.count }

    var hasWaitingReceipts: Bool { !receipts.isEmpty }

    func load() async {
        do {
            receipts = try await inbox.fetchUnfiledReceipts()
        } catch {
            alert = ShopperAlert(
                error,
                fallbackTitle: "Unfiled receipts couldn't be loaded.",
                fallbackMessage: "Pull down to try again."
            )
        }
        hasLoaded = true
    }

    func remove(_ receipt: UnfiledReceipt) async {
        do {
            try await inbox.discard(receiptWithID: receipt.id)
            receipts.removeAll { $0.id == receipt.id }
        } catch {
            alert = ShopperAlert(
                error,
                fallbackTitle: "This receipt couldn't be removed.",
                fallbackMessage: "Please try again in a moment."
            )
        }
    }
}
