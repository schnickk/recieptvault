import Foundation
@testable import ReceiptVault

/// A throwaway folder standing in for the App Group, so tests never touch the real shared container.
final class TemporaryAppGroup {
    let rootURL: URL
    let container: SharedContainer

    init() throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("ReceiptVaultTests-\(UUID().uuidString)", isDirectory: true)
        container = try SharedContainer(rootURL: rootURL)
    }

    func fileExists(named fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: container.receiptFileURL(named: fileName).path)
    }

    func delete() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

/// Counts widget reload requests in a thread-safe way.
final class WidgetReloadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var reloads = 0

    func record() { lock.withLock { reloads += 1 } }
    var count: Int { lock.withLock { reloads } }
}
