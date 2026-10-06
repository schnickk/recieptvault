import Foundation

/// Publisher for SwiftUI previews and the unit-test host. Counts publishes instead of touching the widget.
actor InMemoryWarrantySnapshotPublisher: WarrantySnapshotPublisher {
    private(set) var publishCount = 0

    func publishLatestSnapshot() {
        publishCount += 1
    }
}
