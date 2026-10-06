import XCTest
@testable import ReceiptVault

@MainActor
final class ViewModelTests: XCTestCase {
    private func makeAddPurchaseViewModel(
        mode: AddPurchaseViewModel.Mode = .manual,
        repository: MockPurchaseRepository = MockPurchaseRepository(),
        inbox: MockReceiptInbox = MockReceiptInbox()
    ) -> AddPurchaseViewModel {
        AddPurchaseViewModel(
            mode: mode,
            recordPurchase: RecordPurchase(
                repository: repository, snapshotPublisher: MockWarrantySnapshotPublisher(), now: TestClock.now, calendar: TestClock.calendar
            ),
            fileSharedReceipt: FileSharedReceipt(
                purchases: repository, inbox: inbox, snapshotPublisher: MockWarrantySnapshotPublisher(),
                now: TestClock.now, calendar: TestClock.calendar
            ),
            now: TestClock.now
        )
    }

    // MARK: AddPurchaseViewModel

    func test_addPurchase_readsAustralianPriceWithDollarSignAndCommas() {
        let viewModel = makeAddPurchaseViewModel()
        viewModel.priceText = "$1,299.95"

        XCTAssertEqual(viewModel.price, Decimal(string: "1299.95"))
    }

    func test_addPurchase_asksForDollarsAndCents_whenPriceIsNotANumber() async {
        let repository = MockPurchaseRepository()
        let viewModel = makeAddPurchaseViewModel(repository: repository)
        viewModel.itemName = "Kettle"
        viewModel.retailer = "Kmart"
        viewModel.priceText = "12abc"

        let saved = await viewModel.save()

        XCTAssertFalse(saved)
        XCTAssertNil(viewModel.price)
        XCTAssertEqual(viewModel.alert?.title, "Enter the price as dollars and cents.")
        let savedPurchases = await repository.savedPurchases
        XCTAssertTrue(savedPurchases.isEmpty)
    }

    func test_addPurchase_cannotSaveUntilItemRetailerAndPriceAreEntered() {
        let viewModel = makeAddPurchaseViewModel()
        XCTAssertFalse(viewModel.canSave)

        viewModel.itemName = "Kettle"
        viewModel.retailer = "Kmart"
        viewModel.priceText = "39"

        XCTAssertTrue(viewModel.canSave)
    }

    func test_addPurchase_showsUseCaseErrorAsAlert_whenPriceIsZero() async {
        let repository = MockPurchaseRepository()
        let viewModel = makeAddPurchaseViewModel(repository: repository)
        viewModel.itemName = "Kettle"
        viewModel.retailer = "Kmart"
        viewModel.priceText = "0"

        let saved = await viewModel.save()

        XCTAssertFalse(saved)
        XCTAssertEqual(viewModel.alert?.title, RecordPurchaseError.priceNotAboveZero.errorDescription)
        XCTAssertEqual(viewModel.alert?.message, RecordPurchaseError.priceNotAboveZero.recoverySuggestion)
        let savedPurchases = await repository.savedPurchases
        XCTAssertTrue(savedPurchases.isEmpty)
    }

    func test_addPurchase_filingReceipt_savesPurchaseHoldingReceiptAndClearsInbox() async {
        let receipt = UnfiledReceipt.sharedPDF()
        let repository = MockPurchaseRepository()
        let inbox = MockReceiptInbox(receipts: [receipt])
        let viewModel = makeAddPurchaseViewModel(mode: .filing(receipt), repository: repository, inbox: inbox)
        viewModel.itemName = "Headphones"
        viewModel.retailer = "JB Hi-Fi"
        viewModel.priceText = "549"
        viewModel.includesExtendedWarranty = true
        viewModel.extendedWarrantyMonths = 36

        let saved = await viewModel.save()

        XCTAssertTrue(saved)
        let savedPurchases = await repository.savedPurchases
        let removed = await inbox.removedReceiptIDs
        XCTAssertEqual(savedPurchases.first?.receiptFileName, receipt.fileName)
        XCTAssertEqual(savedPurchases.first?.warranties.map(\.kind), [.manufacturer, .extended])
        XCTAssertEqual(removed, [receipt.id])
    }

    // MARK: ClaimViewModel

    func test_claimViewModel_showsConsumerLawAlert_forEndedWarranty() async {
        let ended = Warranty.manufacturer(endingOn: TestClock.startOfDay(2026, 10, 5))
        let repository = MockPurchaseRepository(purchases: [.fridge(warranties: [ended])])
        let viewModel = ClaimViewModel(
            lodgeWarrantyClaim: LodgeWarrantyClaim(
                repository: repository, snapshotPublisher: MockWarrantySnapshotPublisher(), now: TestClock.now, calendar: TestClock.calendar
            ),
            resolveClaim: ResolveClaim(repository: repository, snapshotPublisher: MockWarrantySnapshotPublisher()),
            now: TestClock.now
        )
        viewModel.faultDescription = "Stopped cooling"

        let lodged = await viewModel.lodgeClaim(onWarrantyWithID: ended.id)

        XCTAssertFalse(lodged)
        XCTAssertEqual(
            viewModel.alert?.title,
            "This warranty ended on 5 October 2026. You may still be covered under the Australian Consumer Law. Contact the retailer directly."
        )
    }

    // MARK: UnfiledReceiptsViewModel

    func test_unfiledReceipts_badgeCountsReceiptsWaitingToBeFiled() async {
        let inbox = MockReceiptInbox(receipts: [.sharedPDF(), .sharedPDF()])
        let viewModel = UnfiledReceiptsViewModel(inbox: inbox)

        await viewModel.load()

        XCTAssertEqual(viewModel.badgeCount, 2)
        XCTAssertTrue(viewModel.hasWaitingReceipts)
    }

    func test_unfiledReceipts_removeDiscardsReceiptAndUpdatesBadge() async {
        let receipt = UnfiledReceipt.sharedPDF()
        let inbox = MockReceiptInbox(receipts: [receipt])
        let viewModel = UnfiledReceiptsViewModel(inbox: inbox)
        await viewModel.load()

        await viewModel.remove(receipt)

        let discarded = await inbox.discardedReceiptIDs
        XCTAssertEqual(discarded, [receipt.id])
        XCTAssertEqual(viewModel.badgeCount, 0)
    }

    // MARK: ExpiringSoonViewModel

    func test_expiringSoon_loadsWarrantiesEndingWithin30Days() async {
        let soon = Warranty.manufacturer(endingOn: TestClock.daysFromToday(9))
        let later = Warranty.manufacturer(endingOn: TestClock.daysFromToday(90))
        let repository = MockPurchaseRepository(purchases: [.fridge(warranties: [soon, later])])
        let viewModel = ExpiringSoonViewModel(repository: repository, now: TestClock.now, calendar: TestClock.calendar)

        await viewModel.load()

        XCTAssertEqual(viewModel.warranties.map(\.id), [soon.id])
        XCTAssertEqual(viewModel.daysLeftLabel(for: viewModel.warranties[0]), "9 days left")
    }
}
