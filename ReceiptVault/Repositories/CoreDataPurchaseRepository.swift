import CoreData

/// PurchaseRepository backed by Core Data.
///
/// Every conversion between managed objects and Domain structs happens in this file, so nothing
/// above the repository ever sees an NSManagedObject or NSManagedObjectContext. Each call uses its
/// own background context and returns plain Sendable structs.
final class CoreDataPurchaseRepository: PurchaseRepository, @unchecked Sendable {
    enum Failure: Error {
        case warrantyNotFound(UUID)
        case claimNotFound(UUID)
    }

    private let container: NSPersistentContainer

    init(container: NSPersistentContainer) {
        self.container = container
    }

    // MARK: Reads

    func fetchAllPurchases() async throws -> [Purchase] {
        try await read { context in
            let request = PurchaseEntity.request()
            request.sortDescriptors = [NSSortDescriptor(key: "purchaseDate", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["warranties", "warranties.claims"]
            return try context.fetch(request).map(Purchase.init)
        }
    }

    func fetchPurchase(id: UUID) async throws -> Purchase? {
        try await read { context in
            try Self.fetchOne(PurchaseEntity.request(), id: id, in: context).map(Purchase.init)
        }
    }

    func fetchWarranty(id: UUID) async throws -> Warranty? {
        try await read { context in
            try Self.fetchOne(WarrantyEntity.request(), id: id, in: context).map(Warranty.init)
        }
    }

    func fetchClaim(id: UUID) async throws -> WarrantyClaim? {
        try await read { context in
            try Self.fetchOne(WarrantyClaimEntity.request(), id: id, in: context).map(WarrantyClaim.init)
        }
    }

    func fetchExpiringWarranties(today: Date, calendar: Calendar) async throws -> [ExpiringWarranty] {
        let startOfToday = calendar.startOfDay(for: today)
        guard let endOfWindow = calendar.date(byAdding: .day, value: ExpiringSoon.windowInDays, to: startOfToday) else {
            return []
        }
        let openStatuses = ClaimStatus.allCases.filter(\.isOpen).map(\.rawValue)

        return try await read { context in
            let request = WarrantyEntity.request()
            request.predicate = NSPredicate(
                format: "expiryDate >= %@ AND expiryDate <= %@ AND SUBQUERY(claims, $c, $c.status IN %@).@count == 0",
                startOfToday as NSDate,
                endOfWindow as NSDate,
                openStatuses
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "expiryDate", ascending: true),
                NSSortDescriptor(key: "purchase.itemName", ascending: true),
            ]
            request.relationshipKeyPathsForPrefetching = ["purchase", "claims"]

            return try context.fetch(request).compactMap { entity -> ExpiringWarranty? in
                guard let purchase = entity.purchase else { return nil }
                let warranty = Warranty(entity)
                return ExpiringWarranty(
                    purchaseID: purchase.id,
                    itemName: purchase.itemName,
                    retailer: purchase.retailer,
                    warranty: warranty,
                    daysRemaining: warranty.daysRemaining(from: today, calendar: calendar)
                )
            }
        }
    }

    // MARK: Writes

    func save(_ purchase: Purchase) async throws {
        try await write { context in
            let entity = try Self.fetchOne(PurchaseEntity.request(), id: purchase.id, in: context)
                ?? Self.insert(PurchaseEntity.self, ReceiptVaultModel.Entity.purchase, into: context)
            entity.update(from: purchase, in: context)
        }
    }

    func deletePurchase(id: UUID) async throws {
        try await write { context in
            // Cascade rules remove its warranties and their claims too.
            if let entity = try Self.fetchOne(PurchaseEntity.request(), id: id, in: context) {
                context.delete(entity)
            }
        }
    }

    func addClaim(_ claim: WarrantyClaim, toWarrantyWithID warrantyID: UUID) async throws {
        try await write { context in
            guard let warranty = try Self.fetchOne(WarrantyEntity.request(), id: warrantyID, in: context) else {
                throw Failure.warrantyNotFound(warrantyID)
            }
            let entity = Self.insert(WarrantyClaimEntity.self, ReceiptVaultModel.Entity.claim, into: context)
            entity.update(from: claim)
            entity.warranty = warranty
        }
    }

    func updateClaim(_ claim: WarrantyClaim) async throws {
        try await write { context in
            guard let entity = try Self.fetchOne(WarrantyClaimEntity.request(), id: claim.id, in: context) else {
                throw Failure.claimNotFound(claim.id)
            }
            entity.update(from: claim)
        }
    }

    // MARK: Context helpers

    private func read<T>(_ work: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.newBackgroundContext()
        return try await context.perform { try work(context) }
    }

    private func write(_ work: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        try await context.perform {
            try work(context)
            if context.hasChanges {
                try context.save()
            }
        }
    }

    fileprivate static func fetchOne<Entity: NSManagedObject>(
        _ request: NSFetchRequest<Entity>,
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> Entity? {
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    fileprivate static func insert<Entity: NSManagedObject>(
        _: Entity.Type,
        _ entityName: String,
        into context: NSManagedObjectContext
    ) -> Entity {
        // Force cast is safe: the entity name and class are paired in ReceiptVaultModel.
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! Entity
    }
}

// MARK: - Managed object → Domain

private extension Purchase {
    init(_ entity: PurchaseEntity) {
        self.init(
            id: entity.id,
            itemName: entity.itemName,
            retailer: entity.retailer,
            purchaseDate: entity.purchaseDate,
            price: entity.price as Decimal,
            category: PurchaseCategory(rawValue: entity.category) ?? .other,
            receiptFileName: entity.receiptFileName,
            // Manufacturer cover first, then by expiry, so the order is the same on every load.
            warranties: entity.warranties
                .map(Warranty.init)
                .sorted { ($0.kind == .manufacturer ? 0 : 1, $0.expiryDate) < ($1.kind == .manufacturer ? 0 : 1, $1.expiryDate) }
        )
    }
}

private extension Warranty {
    init(_ entity: WarrantyEntity) {
        self.init(
            id: entity.id,
            kind: WarrantyKind(rawValue: entity.kind) ?? .manufacturer,
            lengthInMonths: Int(entity.lengthInMonths),
            expiryDate: entity.expiryDate,
            claims: entity.claims
                .map(WarrantyClaim.init)
                .sorted { $0.lodgedOn < $1.lodgedOn }
        )
    }
}

private extension WarrantyClaim {
    init(_ entity: WarrantyClaimEntity) {
        self.init(
            id: entity.id,
            lodgedOn: entity.lodgedOn,
            faultDescription: entity.faultDescription,
            status: ClaimStatus(rawValue: entity.status) ?? .lodged
        )
    }
}

// MARK: - Domain → Managed object

private extension PurchaseEntity {
    /// Copies the purchase across, adding, updating or deleting warranties so the
    /// stored set matches `purchase.warranties` exactly.
    func update(from purchase: Purchase, in context: NSManagedObjectContext) {
        id = purchase.id
        itemName = purchase.itemName
        retailer = purchase.retailer
        purchaseDate = purchase.purchaseDate
        price = purchase.price as NSDecimalNumber
        category = purchase.category.rawValue
        receiptFileName = purchase.receiptFileName

        let stored = Dictionary(uniqueKeysWithValues: warranties.map { ($0.id, $0) })
        let keptIDs = Set(purchase.warranties.map(\.id))
        for entity in warranties where !keptIDs.contains(entity.id) {
            context.delete(entity)
        }
        for warranty in purchase.warranties {
            let entity = stored[warranty.id]
                ?? CoreDataPurchaseRepository.insert(WarrantyEntity.self, ReceiptVaultModel.Entity.warranty, into: context)
            entity.update(from: warranty, in: context)
            entity.purchase = self
        }
    }
}

private extension WarrantyEntity {
    func update(from warranty: Warranty, in context: NSManagedObjectContext) {
        id = warranty.id
        kind = warranty.kind.rawValue
        lengthInMonths = Int16(warranty.lengthInMonths)
        expiryDate = warranty.expiryDate

        let stored = Dictionary(uniqueKeysWithValues: claims.map { ($0.id, $0) })
        let keptIDs = Set(warranty.claims.map(\.id))
        for entity in claims where !keptIDs.contains(entity.id) {
            context.delete(entity)
        }
        for claim in warranty.claims {
            let entity = stored[claim.id]
                ?? CoreDataPurchaseRepository.insert(WarrantyClaimEntity.self, ReceiptVaultModel.Entity.claim, into: context)
            entity.update(from: claim)
            entity.warranty = self
        }
    }
}

private extension WarrantyClaimEntity {
    func update(from claim: WarrantyClaim) {
        id = claim.id
        lodgedOn = claim.lodgedOn
        faultDescription = claim.faultDescription
        status = claim.status.rawValue
    }
}
