import Foundation

/// Keeps the widget up to date. Use cases call this after every change that can affect Expiring Soon.
///
/// It doesn't throw: if the widget can't be updated, the shopper's purchase or claim is still saved,
/// so a widget problem must never turn a successful save into an error.
protocol WarrantySnapshotPublisher: Sendable {
    func publishLatestSnapshot() async
}
