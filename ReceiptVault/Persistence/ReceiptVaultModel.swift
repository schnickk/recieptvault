import CoreData

/// The Core Data model, built in code rather than in an .xcdatamodeld file.
///
/// PurchaseEntity ──warranties (cascade)──▶ WarrantyEntity ──claims (cascade)──▶ WarrantyClaimEntity
///                ◀──purchase (nullify)───                ◀──warranty (nullify)──
///
/// Enums are stored as their String raw values and price as a Decimal, so AUD amounts never pick up
/// floating-point rounding.
enum ReceiptVaultModel {
    enum Entity {
        static let purchase = "PurchaseEntity"
        static let warranty = "WarrantyEntity"
        static let claim = "WarrantyClaimEntity"
    }

    /// One model instance for the whole process. Loading the same entities from two model
    /// instances makes Core Data unsure which class to use, so every container shares this one.
    static let shared: NSManagedObjectModel = makeModel()

    private static func makeModel() -> NSManagedObjectModel {
        let purchase = entity(Entity.purchase)
        let warranty = entity(Entity.warranty)
        let claim = entity(Entity.claim)

        let purchaseWarranties = toMany("warranties", destination: warranty, deleteRule: .cascadeDeleteRule)
        let warrantyPurchase = toOne("purchase", destination: purchase)
        purchaseWarranties.inverseRelationship = warrantyPurchase
        warrantyPurchase.inverseRelationship = purchaseWarranties

        let warrantyClaims = toMany("claims", destination: claim, deleteRule: .cascadeDeleteRule)
        let claimWarranty = toOne("warranty", destination: warranty)
        warrantyClaims.inverseRelationship = claimWarranty
        claimWarranty.inverseRelationship = warrantyClaims

        purchase.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("itemName", .stringAttributeType),
            attribute("retailer", .stringAttributeType),
            attribute("purchaseDate", .dateAttributeType),
            attribute("price", .decimalAttributeType),
            attribute("category", .stringAttributeType),
            attribute("receiptFileName", .stringAttributeType, isOptional: true),
            purchaseWarranties,
        ]

        warranty.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("kind", .stringAttributeType),
            attribute("lengthInMonths", .integer16AttributeType),
            attribute("expiryDate", .dateAttributeType),
            warrantyPurchase,
            warrantyClaims,
        ]

        claim.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("lodgedOn", .dateAttributeType),
            attribute("faultDescription", .stringAttributeType),
            attribute("status", .stringAttributeType),
            claimWarranty,
        ]

        let model = NSManagedObjectModel()
        model.entities = [purchase, warranty, claim]
        return model
    }

    private static func entity(_ name: String) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        // Matches the @objc(...) name on the NSManagedObject subclass in ManagedEntities.swift.
        entity.managedObjectClassName = name
        return entity
    }

    private static func attribute(_ name: String, _ type: NSAttributeType, isOptional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }

    private static func toMany(_ name: String, destination: NSEntityDescription, deleteRule: NSDeleteRule) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = 0
        relationship.maxCount = 0
        relationship.deleteRule = deleteRule
        relationship.isOptional = true
        return relationship
    }

    private static func toOne(_ name: String, destination: NSEntityDescription) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = 0
        relationship.maxCount = 1
        relationship.deleteRule = .nullifyDeleteRule
        relationship.isOptional = true
        return relationship
    }
}
