import CoreData

// Managed object classes for the entities in ReceiptVaultModel.
// Only Persistence/ and CoreDataPurchaseRepository use these. Everything above the
// repository works with the Domain structs instead.

@objc(PurchaseEntity)
final class PurchaseEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var itemName: String
    @NSManaged var retailer: String
    @NSManaged var purchaseDate: Date
    @NSManaged var price: NSDecimalNumber
    @NSManaged var category: String
    @NSManaged var receiptFileName: String?
    @NSManaged var warranties: Set<WarrantyEntity>

    static func request() -> NSFetchRequest<PurchaseEntity> {
        NSFetchRequest(entityName: ReceiptVaultModel.Entity.purchase)
    }
}

@objc(WarrantyEntity)
final class WarrantyEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var kind: String
    @NSManaged var lengthInMonths: Int16
    @NSManaged var expiryDate: Date
    @NSManaged var purchase: PurchaseEntity?
    @NSManaged var claims: Set<WarrantyClaimEntity>

    static func request() -> NSFetchRequest<WarrantyEntity> {
        NSFetchRequest(entityName: ReceiptVaultModel.Entity.warranty)
    }
}

@objc(WarrantyClaimEntity)
final class WarrantyClaimEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var lodgedOn: Date
    @NSManaged var faultDescription: String
    @NSManaged var status: String
    @NSManaged var warranty: WarrantyEntity?

    static func request() -> NSFetchRequest<WarrantyClaimEntity> {
        NSFetchRequest(entityName: ReceiptVaultModel.Entity.claim)
    }
}
