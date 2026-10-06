import CoreData

/// Owns the Core Data stack.
///
/// The SQLite file lives in the app's own Application Support folder, not the App Group.
/// Purchases belong to the app alone. Only the receipt inbox and the widget snapshot are
/// shared, as small JSON files.
final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    static var storeURL: URL {
        NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("ReceiptVault.sqlite")
    }

    /// - Parameter inMemory: true for previews and test hosts. Nothing is written to disk.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ReceiptVault", managedObjectModel: ReceiptVaultModel.shared)

        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else {
            description.type = NSSQLiteStoreType
            description.url = Self.storeURL
        }
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                // Without its store the app can't show or save anything, so stop here
                // with a clear message rather than carry on in a broken state.
                fatalError("Receipt Vault couldn't open its purchase store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
