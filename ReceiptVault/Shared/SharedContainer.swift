import Foundation

enum SharedContainerError: LocalizedError, Equatable {
    case appGroupUnavailable

    var errorDescription: String? {
        "Receipt Vault couldn't open Unfiled Receipts."
    }

    var recoverySuggestion: String? {
        "Try again in a moment. If it keeps happening, restart your device."
    }
}

/// The App Group folder shared by the app, the Share Extension and the widget.
///
///     <App Group>/
///         ReceiptInbox/            receipt files, named <uuid>.<ext>
///         ReceiptInbox/inbox.json  receipts waiting to be filed
///         Widget/                  the widget's snapshot (Phase 5)
///
/// Purchases themselves stay in the app's private Core Data store.
struct SharedContainer: Sendable {
    static let appGroupIdentifier = "group.com.lucas.receiptvault"

    let rootURL: URL

    var receiptInboxDirectoryURL: URL { rootURL.appendingPathComponent("ReceiptInbox", isDirectory: true) }
    var inboxFileURL: URL { receiptInboxDirectoryURL.appendingPathComponent("inbox.json", isDirectory: false) }
    var widgetDirectoryURL: URL { rootURL.appendingPathComponent("Widget", isDirectory: true) }

    func receiptFileURL(named fileName: String) -> URL {
        receiptInboxDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Opens the App Group folder and creates the ReceiptInbox and Widget folders if they're missing.
    /// Throws, rather than crashing, if the App Group isn't available (for example, a missing entitlement).
    init(appGroupIdentifier: String = SharedContainer.appGroupIdentifier) throws {
        guard let rootURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw SharedContainerError.appGroupUnavailable
        }
        try self.init(rootURL: rootURL)
    }

    /// Uses any folder as the shared root.
    init(rootURL: URL) throws {
        self.rootURL = rootURL
        for directory in [receiptInboxDirectoryURL, widgetDirectoryURL] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
