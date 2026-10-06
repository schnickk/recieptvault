import Foundation

/// Reads and writes Widget/warranty-snapshot.json in the App Group.
enum WarrantySnapshotFile {
    static let fileName = "warranty-snapshot.json"

    static func url(in container: SharedContainer) -> URL {
        container.widgetDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
    }

    /// Writes atomically, so the widget never reads a half-written file. Returns where it wrote.
    @discardableResult
    static func write(_ snapshot: WarrantySnapshot, to container: SharedContainer) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = url(in: container)
        try encoder.encode(snapshot).write(to: url, options: .atomic)
        return url
    }

    /// The saved snapshot, or nil if there isn't one yet or it can't be read.
    static func read(from container: SharedContainer) -> WarrantySnapshot? {
        guard let data = try? Data(contentsOf: url(in: container)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WarrantySnapshot.self, from: data)
    }
}
