import Foundation
@testable import ReceiptVault

/// Counts how many times a use case asked for the widget to be refreshed.
actor MockWarrantySnapshotPublisher: WarrantySnapshotPublisher {
    private(set) var publishCount = 0

    func publishLatestSnapshot() {
        publishCount += 1
    }
}
