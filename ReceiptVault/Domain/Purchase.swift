import Foundation

/// Something the shopper bought and wants to keep the receipt and warranties for.
struct Purchase: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var itemName: String
    var retailer: String
    var purchaseDate: Date
    /// What was paid, in Australian dollars.
    var price: Decimal
    var category: PurchaseCategory
    /// File name of the receipt in the App Group's receipt folder, if one has been filed.
    var receiptFileName: String?
    var warranties: [Warranty]

    init(
        id: UUID = UUID(),
        itemName: String,
        retailer: String,
        purchaseDate: Date,
        price: Decimal,
        category: PurchaseCategory,
        receiptFileName: String? = nil,
        warranties: [Warranty] = []
    ) {
        self.id = id
        self.itemName = itemName
        self.retailer = retailer
        self.purchaseDate = purchaseDate
        self.price = price
        self.category = category
        self.receiptFileName = receiptFileName
        self.warranties = warranties
    }

    var hasReceipt: Bool { receiptFileName != nil }
}
