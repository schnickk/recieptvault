import Foundation
import Observation

/// Backs AddPurchaseView, both for entering a purchase by hand and for filing an unfiled receipt.
@MainActor
@Observable
final class AddPurchaseViewModel {
    enum Mode: Equatable {
        case manual
        case filing(UnfiledReceipt)
    }

    var itemName = ""
    var retailer = ""
    var purchaseDate: Date
    /// Typed text, so "$1,299.95" and "1299.95" both work.
    var priceText = ""
    var category: PurchaseCategory = .electronics
    var manufacturerWarrantyMonths = 12
    var includesExtendedWarranty = false
    var extendedWarrantyMonths = 24
    private(set) var isSaving = false
    var alert: ShopperAlert?

    let mode: Mode
    private let recordPurchase: RecordPurchase
    private let fileSharedReceipt: FileSharedReceipt
    private let now: () -> Date

    init(mode: Mode, recordPurchase: RecordPurchase, fileSharedReceipt: FileSharedReceipt, now: @escaping () -> Date) {
        self.mode = mode
        self.recordPurchase = recordPurchase
        self.fileSharedReceipt = fileSharedReceipt
        self.now = now
        purchaseDate = now()
    }

    var title: String {
        switch mode {
        case .manual: "Add Purchase"
        case .filing: "File Receipt"
        }
    }

    var receipt: UnfiledReceipt? {
        if case let .filing(receipt) = mode { receipt } else { nil }
    }

    /// The date picker stops at today. RecordPurchase still enforces the rule.
    var latestPurchaseDate: Date { now() }

    /// Dollars with up to two decimal places, e.g. "549", "549.95" or "$1,299.95".
    /// Anything else, such as "12abc", is nil rather than being partly read as 12.
    var price: Decimal? {
        let cleaned = priceText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard cleaned.range(of: #"^\d+(\.\d{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_AU"))
    }

    var canSave: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty
            && !retailer.trimmingCharacters(in: .whitespaces).isEmpty
            && !priceText.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSaving
    }

    /// Returns true once the purchase is saved, so the view can close.
    func save() async -> Bool {
        guard let price else {
            alert = ShopperAlert(
                title: "Enter the price as dollars and cents.",
                message: "Use numbers only, for example 549.95. Check your receipt for the amount you paid."
            )
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let request = makeRequest(price: price)
        do {
            switch mode {
            case .manual:
                try await recordPurchase.execute(request)
            case let .filing(receipt):
                try await fileSharedReceipt.execute(receiptID: receipt.id, into: .newPurchase(request))
            }
            return true
        } catch {
            alert = ShopperAlert(error, fallbackTitle: "Your purchase couldn't be saved.")
            return false
        }
    }

    private func makeRequest(price: Decimal) -> RecordPurchase.Request {
        var warranties = [RecordPurchase.WarrantyTerms(kind: .manufacturer, lengthInMonths: manufacturerWarrantyMonths)]
        if includesExtendedWarranty {
            warranties.append(.init(kind: .extended, lengthInMonths: extendedWarrantyMonths))
        }
        return RecordPurchase.Request(
            itemName: itemName,
            retailer: retailer,
            purchaseDate: purchaseDate,
            price: price,
            category: category,
            warranties: warranties
        )
    }
}
