import Foundation

enum ReceiptInboxError: LocalizedError, Equatable {
    case inboxUnreadable

    var errorDescription: String? {
        "Your unfiled receipts couldn't be read."
    }

    var recoverySuggestion: String? {
        "Share the receipt again from Mail, Photos or Files. Purchases you've already filed are safe."
    }
}

/// Reads and writes the shared receipt inbox: the receipt files and inbox.json.
///
/// The app and the Share Extension are separate processes that can run at the same time, so every
/// read-modify-write of inbox.json happens inside an NSFileCoordinator block and is written atomically.
/// A reader never sees a half-written file, and two writers never overwrite each other's changes.
struct ReceiptInboxStore: Sendable {
    let container: SharedContainer

    func loadReceipts() throws -> [UnfiledReceipt] {
        try coordinate(writing: false) { url in try decodeReceipts(at: url) }
    }

    /// Copies a shared file into ReceiptInbox/<uuid>.<ext> and adds it to the inbox.
    @discardableResult
    func addReceipt(
        copyingFileAt sourceURL: URL,
        fileExtension: String,
        originalFileName: String,
        receivedAt: Date = Date()
    ) throws -> UnfiledReceipt {
        let fileName = newFileName(fileExtension: fileExtension)
        try FileManager.default.copyItem(at: sourceURL, to: container.receiptFileURL(named: fileName))
        return try addEntry(fileName: fileName, originalFileName: originalFileName, receivedAt: receivedAt)
    }

    /// Writes shared data into ReceiptInbox/<uuid>.<ext> and adds it to the inbox.
    @discardableResult
    func addReceipt(
        data: Data,
        fileExtension: String,
        originalFileName: String,
        receivedAt: Date = Date()
    ) throws -> UnfiledReceipt {
        let fileName = try saveFile(data, fileExtension: fileExtension)
        return try addEntry(fileName: fileName, originalFileName: originalFileName, receivedAt: receivedAt)
    }

    /// Writes a receipt file without adding an inbox entry, and returns its file name.
    func saveFile(_ data: Data, fileExtension: String) throws -> String {
        let fileName = newFileName(fileExtension: fileExtension)
        try data.write(to: container.receiptFileURL(named: fileName), options: .atomic)
        return fileName
    }

    /// Adds an entry for a receipt file that's already in ReceiptInbox/.
    func add(_ receipt: UnfiledReceipt) throws {
        try update { receipts in
            receipts.removeAll { $0.id == receipt.id }
            receipts.append(receipt)
        }
    }

    /// Removes the inbox entry but keeps the file, because a filed purchase now points at it.
    func removeEntry(id: UUID) throws {
        try update { receipts in receipts.removeAll { $0.id == id } }
    }

    /// Removes the inbox entry and deletes its file. Used when the shopper discards a receipt.
    func discard(id: UUID) throws {
        var discarded: UnfiledReceipt?
        try update { receipts in
            discarded = receipts.first { $0.id == id }
            receipts.removeAll { $0.id == id }
        }
        if let discarded {
            try? FileManager.default.removeItem(at: container.receiptFileURL(named: discarded.fileName))
        }
    }

    // MARK: Private

    private func addEntry(fileName: String, originalFileName: String, receivedAt: Date) throws -> UnfiledReceipt {
        let receipt = UnfiledReceipt(fileName: fileName, originalFileName: originalFileName, receivedAt: receivedAt)
        do {
            try add(receipt)
        } catch {
            // Don't leave a file behind that nothing points to.
            try? FileManager.default.removeItem(at: container.receiptFileURL(named: fileName))
            throw error
        }
        return receipt
    }

    private func newFileName(fileExtension: String) -> String {
        let cleanExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return cleanExtension.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(cleanExtension)"
    }

    private func update(_ change: (inout [UnfiledReceipt]) -> Void) throws {
        try coordinate(writing: true) { url in
            var receipts = try decodeReceipts(at: url)
            change(&receipts)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(receipts).write(to: url, options: .atomic)
        }
    }

    private func decodeReceipts(at url: URL) throws -> [UnfiledReceipt] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([UnfiledReceipt].self, from: Data(contentsOf: url))
        } catch {
            throw ReceiptInboxError.inboxUnreadable
        }
    }

    /// Runs `body` while holding a cross-process lock on inbox.json.
    private func coordinate<T>(writing: Bool, _ body: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<T, Error>?
        if writing {
            coordinator.coordinate(writingItemAt: container.inboxFileURL, options: .forMerging, error: &coordinationError) { url in
                result = Result { try body(url) }
            }
        } else {
            coordinator.coordinate(readingItemAt: container.inboxFileURL, options: [], error: &coordinationError) { url in
                result = Result { try body(url) }
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ReceiptInboxError.inboxUnreadable }
        return try result.get()
    }
}
