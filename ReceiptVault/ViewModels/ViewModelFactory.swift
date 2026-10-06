import Foundation

/// What a view may ask the composition root for: new ViewModels, nothing else.
/// Views never see a repository, so they can't bypass the use cases.
@MainActor
protocol ViewModelFactory {
    func makePurchaseListViewModel() -> PurchaseListViewModel
    func makeExpiringSoonViewModel() -> ExpiringSoonViewModel
    func makeUnfiledReceiptsViewModel() -> UnfiledReceiptsViewModel
    /// Pass a receipt to file it against the new purchase, or nil for manual entry.
    func makeAddPurchaseViewModel(filing receipt: UnfiledReceipt?) -> AddPurchaseViewModel
    func makeClaimViewModel() -> ClaimViewModel
}
