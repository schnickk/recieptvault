import Foundation

enum FileSharedReceiptError: LocalizedError, Equatable {
    case receiptNoLongerInInbox
    case purchaseNotFound
    case purchaseAlreadyHasReceipt(itemName: String)
    case purchaseDetailsInvalid(RecordPurchaseError)
    case couldNotFile
    case filedButStillInInbox

    var errorDescription: String? {
        switch self {
        case .receiptNoLongerInInbox:
            "This receipt is no longer in Unfiled Receipts."
        case .purchaseNotFound:
            "We couldn't find that purchase."
        case let .purchaseAlreadyHasReceipt(itemName):
            "\(itemName) already has a receipt."
        case let .purchaseDetailsInvalid(reason):
            reason.errorDescription
        case .couldNotFile:
            "This receipt couldn't be filed."
        case .filedButStillInInbox:
            "Your receipt was filed, but it's still showing in Unfiled Receipts."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .receiptNoLongerInInbox:
            "It may already have been filed or removed. Check the purchase it belongs to in My Purchases."
        case .purchaseNotFound:
            "It may have been deleted. Choose another purchase or add a new one for this receipt."
        case .purchaseAlreadyHasReceipt:
            "Each purchase holds one receipt. Choose another purchase or add a new one for this receipt."
        case let .purchaseDetailsInvalid(reason):
            reason.recoverySuggestion
        case .couldNotFile:
            "Your receipt is still safe in Unfiled Receipts. Please try again."
        case .filedButStillInInbox:
            "You can safely remove it from Unfiled Receipts. The purchase already holds the receipt."
        }
    }
}

/// Files a receipt from the Unfiled Receipts inbox against a new or existing purchase.
struct FileSharedReceipt: Sendable {
    enum Destination: Hashable, Sendable {
        case newPurchase(RecordPurchase.Request)
        case existingPurchase(id: UUID)
    }

    let purchases: any PurchaseRepository
    let inbox: any ReceiptInboxRepository
    let snapshotPublisher: any WarrantySnapshotPublisher
    let recordPurchase: RecordPurchase

    init(
        purchases: any PurchaseRepository,
        inbox: any ReceiptInboxRepository,
        snapshotPublisher: any WarrantySnapshotPublisher,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.purchases = purchases
        self.inbox = inbox
        self.snapshotPublisher = snapshotPublisher
        self.recordPurchase = RecordPurchase(repository: purchases, snapshotPublisher: snapshotPublisher, now: now, calendar: calendar)
    }

    /// Saves the purchase first and only then removes the inbox entry,
    /// so a failed save never loses the shopper's receipt.
    @discardableResult
    func execute(receiptID: UUID, into destination: Destination) async throws -> Purchase {
        let receipt = try await receiptInInbox(id: receiptID)
        let purchase = try await purchase(holding: receipt, destination: destination)

        do {
            try await purchases.save(purchase)
        } catch {
            throw FileSharedReceiptError.couldNotFile
        }
        // The purchase is saved, so the widget is refreshed even if clearing the inbox fails below.
        await snapshotPublisher.publishLatestSnapshot()
        do {
            try await inbox.remove(receiptWithID: receipt.id)
        } catch {
            throw FileSharedReceiptError.filedButStillInInbox
        }
        return purchase
    }

    private func receiptInInbox(id: UUID) async throws -> UnfiledReceipt {
        let receipts: [UnfiledReceipt]
        do {
            receipts = try await inbox.fetchUnfiledReceipts()
        } catch {
            throw FileSharedReceiptError.couldNotFile
        }
        guard let receipt = receipts.first(where: { $0.id == id }) else {
            throw FileSharedReceiptError.receiptNoLongerInInbox
        }
        return receipt
    }

    private func purchase(holding receipt: UnfiledReceipt, destination: Destination) async throws -> Purchase {
        switch destination {
        case let .newPurchase(request):
            do {
                return try recordPurchase.makePurchase(from: request, receiptFileName: receipt.fileName)
            } catch let reason as RecordPurchaseError {
                throw FileSharedReceiptError.purchaseDetailsInvalid(reason)
            }

        case let .existingPurchase(id):
            let existing: Purchase?
            do {
                existing = try await purchases.fetchPurchase(id: id)
            } catch {
                throw FileSharedReceiptError.couldNotFile
            }
            guard var purchase = existing else {
                throw FileSharedReceiptError.purchaseNotFound
            }
            guard !purchase.hasReceipt else {
                throw FileSharedReceiptError.purchaseAlreadyHasReceipt(itemName: purchase.itemName)
            }
            purchase.receiptFileName = receipt.fileName
            return purchase
        }
    }
}
