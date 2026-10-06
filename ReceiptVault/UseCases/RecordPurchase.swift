import Foundation

enum RecordPurchaseError: LocalizedError, Equatable {
    case purchaseDateInFuture
    case priceNotAboveZero
    case warrantyLengthOutOfRange(kind: WarrantyKind, months: Int)
    case couldNotSave

    var errorDescription: String? {
        switch self {
        case .purchaseDateInFuture:
            "The purchase date is in the future."
        case .priceNotAboveZero:
            "The price must be more than $0.00."
        case let .warrantyLengthOutOfRange(kind, months):
            "A \(kind.displayName.lowercased()) can't be \(months) months long."
        case .couldNotSave:
            "Your purchase couldn't be saved."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .purchaseDateInFuture:
            "Choose the day you bought it. That can be today or any earlier day."
        case .priceNotAboveZero:
            "Enter what you paid in Australian dollars, as shown on your receipt."
        case .warrantyLengthOutOfRange:
            "Enter a length from 0 to 120 months (10 years). Check the warranty card or ask the retailer if you're unsure."
        case .couldNotSave:
            "Please try again. If it keeps happening, close and reopen Receipt Vault."
        }
    }
}

/// Records a new purchase and works out when each of its warranties ends.
struct RecordPurchase: Sendable {
    struct WarrantyTerms: Hashable, Sendable {
        var kind: WarrantyKind
        var lengthInMonths: Int
    }

    struct Request: Hashable, Sendable {
        var itemName: String
        var retailer: String
        var purchaseDate: Date
        var price: Decimal
        var category: PurchaseCategory
        var warranties: [WarrantyTerms]
    }

    let repository: any PurchaseRepository
    let snapshotPublisher: any WarrantySnapshotPublisher
    let now: @Sendable () -> Date
    let calendar: Calendar

    init(
        repository: any PurchaseRepository,
        snapshotPublisher: any WarrantySnapshotPublisher,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.snapshotPublisher = snapshotPublisher
        self.now = now
        self.calendar = calendar
    }

    @discardableResult
    func execute(_ request: Request) async throws -> Purchase {
        let purchase = try makePurchase(from: request)
        do {
            try await repository.save(purchase)
        } catch {
            throw RecordPurchaseError.couldNotSave
        }
        await snapshotPublisher.publishLatestSnapshot()
        return purchase
    }

    /// Applies every purchase rule and builds the purchase without saving it.
    /// FileSharedReceipt calls this too, so both ways of adding a purchase share one set of rules.
    func makePurchase(from request: Request, receiptFileName: String? = nil) throws -> Purchase {
        let purchaseDay = calendar.startOfDay(for: request.purchaseDate)
        guard purchaseDay <= calendar.startOfDay(for: now()) else {
            throw RecordPurchaseError.purchaseDateInFuture
        }
        guard request.price > 0 else {
            throw RecordPurchaseError.priceNotAboveZero
        }

        let warranties = try request.warranties.map { terms in
            guard Warranty.allowedLengthInMonths.contains(terms.lengthInMonths),
                  let expiryDate = calendar.date(byAdding: .month, value: terms.lengthInMonths, to: purchaseDay)
            else {
                throw RecordPurchaseError.warrantyLengthOutOfRange(kind: terms.kind, months: terms.lengthInMonths)
            }
            return Warranty(kind: terms.kind, lengthInMonths: terms.lengthInMonths, expiryDate: expiryDate)
        }

        return Purchase(
            itemName: request.itemName.trimmingCharacters(in: .whitespacesAndNewlines),
            retailer: request.retailer.trimmingCharacters(in: .whitespacesAndNewlines),
            purchaseDate: request.purchaseDate,
            price: request.price,
            category: request.category,
            receiptFileName: receiptFileName,
            warranties: warranties
        )
    }
}
