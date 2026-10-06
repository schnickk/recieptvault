import Foundation
import WidgetKit

/// Builds the widget snapshot from the Expiring Soon query, writes Widget/warranty-snapshot.json
/// to the App Group, and asks WidgetKit to redraw.
struct AppGroupWarrantySnapshotPublisher: WarrantySnapshotPublisher {
    let repository: any PurchaseRepository
    let sharedContainer: SharedContainer?
    let now: @Sendable () -> Date
    let calendar: Calendar
    /// Asks WidgetKit to redraw. Tests replace it so they never touch the real widget.
    let reloadWidgets: @Sendable () -> Void

    init(
        repository: any PurchaseRepository,
        sharedContainer: SharedContainer?,
        now: @escaping @Sendable () -> Date,
        calendar: Calendar,
        reloadWidgets: @escaping @Sendable () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.repository = repository
        self.sharedContainer = sharedContainer
        self.now = now
        self.calendar = calendar
        self.reloadWidgets = reloadWidgets
    }

    func publishLatestSnapshot() async {
        guard let sharedContainer else {
            debugLog("App Group unavailable, widget not updated.")
            return
        }
        do {
            let today = now()
            let expiring = try await repository.fetchExpiringWarranties(today: today, calendar: calendar)
            let url = try WarrantySnapshotFile.write(WarrantySnapshot(expiring: expiring, generatedAt: today), to: sharedContainer)
            reloadWidgets()
            debugLog("Wrote \(url.path)")
        } catch {
            debugLog("Widget not updated: \(error)")
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[WarrantySnapshot] \(message)")
        #endif
    }
}
