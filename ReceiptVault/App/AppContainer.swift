import Foundation

/// The composition root: the one place that picks concrete repositories and wires up the use cases.
/// ViewModels receive what they need from here, so no screen ever creates its own storage.
final class AppContainer: Sendable {
    enum SampleDataPolicy: Sendable {
        /// Never add sample purchases (release builds and unit-test hosts).
        case none
        /// Add sample purchases once, the first time the app runs (DEBUG builds).
        case onFirstLaunch
        /// Add sample purchases whenever the store is empty (SwiftUI previews).
        case whenStoreIsEmpty
    }

    let purchaseRepository: any PurchaseRepository
    let receiptInbox: any ReceiptInboxRepository
    let snapshotPublisher: any WarrantySnapshotPublisher
    /// The App Group folder, or nil if it couldn't be opened. Receipt files live here.
    let sharedContainer: SharedContainer?

    let recordPurchase: RecordPurchase
    let fileSharedReceipt: FileSharedReceipt
    let lodgeWarrantyClaim: LodgeWarrantyClaim
    let resolveClaim: ResolveClaim

    let now: @Sendable () -> Date
    let calendar: Calendar
    let sampleDataPolicy: SampleDataPolicy

    init(
        purchaseRepository: any PurchaseRepository,
        receiptInbox: any ReceiptInboxRepository,
        snapshotPublisher: any WarrantySnapshotPublisher,
        sharedContainer: SharedContainer? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current,
        sampleDataPolicy: SampleDataPolicy = .none
    ) {
        self.purchaseRepository = purchaseRepository
        self.receiptInbox = receiptInbox
        self.snapshotPublisher = snapshotPublisher
        self.sharedContainer = sharedContainer
        self.now = now
        self.calendar = calendar
        self.sampleDataPolicy = sampleDataPolicy

        recordPurchase = RecordPurchase(
            repository: purchaseRepository, snapshotPublisher: snapshotPublisher, now: now, calendar: calendar
        )
        fileSharedReceipt = FileSharedReceipt(
            purchases: purchaseRepository, inbox: receiptInbox, snapshotPublisher: snapshotPublisher, now: now, calendar: calendar
        )
        lodgeWarrantyClaim = LodgeWarrantyClaim(
            repository: purchaseRepository, snapshotPublisher: snapshotPublisher, now: now, calendar: calendar
        )
        resolveClaim = ResolveClaim(repository: purchaseRepository, snapshotPublisher: snapshotPublisher)
    }

    /// The container the running app uses.
    static func live() -> AppContainer {
        // Unit tests run inside the app, so give them a throwaway store, an in-memory inbox and no sample data.
        let isUnitTestHost = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let persistence = isUnitTestHost ? PersistenceController(inMemory: true) : .shared
        let sharedContainer = try? SharedContainer()

        #if DEBUG
        let sampleDataPolicy: SampleDataPolicy = isUnitTestHost ? .none : .onFirstLaunch
        #else
        let sampleDataPolicy: SampleDataPolicy = .none
        #endif

        let purchaseRepository = CoreDataPurchaseRepository(container: persistence.container)
        let receiptInbox: any ReceiptInboxRepository = isUnitTestHost
            ? InMemoryReceiptInbox()
            : AppGroupReceiptInbox(sharedContainer: sharedContainer)
        let snapshotPublisher: any WarrantySnapshotPublisher = isUnitTestHost
            ? InMemoryWarrantySnapshotPublisher()
            : AppGroupWarrantySnapshotPublisher(
                repository: purchaseRepository,
                sharedContainer: sharedContainer,
                now: { Date() },
                calendar: .current
            )

        return AppContainer(
            purchaseRepository: purchaseRepository,
            receiptInbox: receiptInbox,
            snapshotPublisher: snapshotPublisher,
            sharedContainer: sharedContainer,
            sampleDataPolicy: sampleDataPolicy
        )
    }

    /// An in-memory container filled with sample purchases, for SwiftUI previews.
    static func preview() -> AppContainer {
        AppContainer(
            purchaseRepository: CoreDataPurchaseRepository(container: PersistenceController(inMemory: true).container),
            receiptInbox: InMemoryReceiptInbox(),
            snapshotPublisher: InMemoryWarrantySnapshotPublisher(),
            sharedContainer: try? SharedContainer(),
            sampleDataPolicy: .whenStoreIsEmpty
        )
    }

    /// Work that must finish before the first screen loads its data.
    func prepareForLaunch() async {
        #if DEBUG
        switch sampleDataPolicy {
        case .none:
            break
        case .onFirstLaunch:
            await SampleData.seedOnFirstLaunch(using: self)
        case .whenStoreIsEmpty:
            await SampleData.seedIfStoreIsEmpty(using: self)
        }
        #endif
        // Days left change overnight, so bring the widget up to date on every launch.
        await snapshotPublisher.publishLatestSnapshot()
    }
}

// MARK: - ViewModels

extension AppContainer: ViewModelFactory {
    @MainActor
    func makePurchaseListViewModel() -> PurchaseListViewModel {
        PurchaseListViewModel(
            repository: purchaseRepository,
            receiptFileURL: { [sharedContainer] fileName in sharedContainer?.receiptFileURL(named: fileName) },
            now: now,
            calendar: calendar
        )
    }

    @MainActor
    func makeExpiringSoonViewModel() -> ExpiringSoonViewModel {
        ExpiringSoonViewModel(repository: purchaseRepository, now: now, calendar: calendar)
    }

    @MainActor
    func makeUnfiledReceiptsViewModel() -> UnfiledReceiptsViewModel {
        UnfiledReceiptsViewModel(inbox: receiptInbox)
    }

    @MainActor
    func makeAddPurchaseViewModel(filing receipt: UnfiledReceipt?) -> AddPurchaseViewModel {
        AddPurchaseViewModel(
            mode: receipt.map { .filing($0) } ?? .manual,
            recordPurchase: recordPurchase,
            fileSharedReceipt: fileSharedReceipt,
            now: now
        )
    }

    @MainActor
    func makeClaimViewModel() -> ClaimViewModel {
        ClaimViewModel(lodgeWarrantyClaim: lodgeWarrantyClaim, resolveClaim: resolveClaim, now: now)
    }
}
