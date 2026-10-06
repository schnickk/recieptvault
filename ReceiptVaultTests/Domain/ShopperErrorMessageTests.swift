import XCTest
@testable import ReceiptVault

/// Every error a shopper can see must explain what happened and what to do next,
/// in plain words with no developer jargon.
final class ShopperErrorMessageTests: XCTestCase {
    private let allErrors: [any LocalizedError] = [
        RecordPurchaseError.purchaseDateInFuture,
        RecordPurchaseError.priceNotAboveZero,
        RecordPurchaseError.warrantyLengthOutOfRange(kind: .manufacturer, months: 121),
        RecordPurchaseError.couldNotSave,
        FileSharedReceiptError.receiptNoLongerInInbox,
        FileSharedReceiptError.purchaseNotFound,
        FileSharedReceiptError.purchaseAlreadyHasReceipt(itemName: "Fridge"),
        FileSharedReceiptError.purchaseDetailsInvalid(.priceNotAboveZero),
        FileSharedReceiptError.couldNotFile,
        FileSharedReceiptError.filedButStillInInbox,
        LodgeWarrantyClaimError.warrantyNotFound,
        LodgeWarrantyClaimError.warrantyEnded(endedOn: TestClock.yesterday),
        LodgeWarrantyClaimError.openClaimAlreadyExists(lodgedOn: TestClock.yesterday),
        LodgeWarrantyClaimError.couldNotSave,
        ResolveClaimError.claimNotFound,
        ResolveClaimError.claimAlreadyClosed(status: .resolved),
        ResolveClaimError.couldNotSave,
        SharedContainerError.appGroupUnavailable,
        ReceiptInboxError.inboxUnreadable,
    ]

    func test_everyError_explainsWhatHappenedAndWhatToDoNext_inShopperLanguage() {
        let jargon = ["repository", "core data", "nil", "context", "uuid", "error", "inbox.json"]

        for error in allErrors {
            let description = error.errorDescription ?? ""
            let suggestion = error.recoverySuggestion ?? ""
            XCTAssertFalse(description.isEmpty, "\(error) has no errorDescription")
            XCTAssertFalse(suggestion.isEmpty, "\(error) has no recoverySuggestion")
            for word in jargon {
                XCTAssertFalse((description + " " + suggestion).lowercased().contains(word), "\(error) mentions \"\(word)\"")
            }
        }
    }
}
