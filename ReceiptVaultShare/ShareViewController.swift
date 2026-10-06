import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The Share Extension. Saves the first photo or PDF it's given to the App Group's receipt inbox,
/// confirms, and closes. Filing happens later, in the app.
///
/// Every path ends in completeRequest or cancelRequest, so the share sheet never gets stuck.
final class ShareViewController: UIViewController {
    private let status = ShareStatus()
    private var hasFinished = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let host = UIHostingController(rootView: ShareStatusView(status: status) { [weak self] in
            self?.cancel()
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { await saveSharedReceipt() }
    }

    private func saveSharedReceipt() async {
        do {
            let store = ReceiptInboxStore(container: try SharedContainer())
            let attachment = try Self.firstReceiptAttachment(in: extensionContext)
            try await Self.save(attachment, to: store)
            status.phase = .saved
            try? await Task.sleep(for: .seconds(1))
            complete()
        } catch {
            let localized = error as? LocalizedError
            status.phase = .failed(
                title: localized?.errorDescription ?? "This receipt couldn't be saved.",
                message: localized?.recoverySuggestion
                    ?? "Please try again. If it keeps happening, open Receipt Vault and add the purchase there."
            )
        }
    }

    private func complete() {
        guard !hasFinished else { return }
        hasFinished = true
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        guard !hasFinished else { return }
        hasFinished = true
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    // MARK: Reading the shared item

    private struct Attachment {
        let provider: NSItemProvider
        let type: UTType
    }

    /// The first attachment that is a PDF or an image. Uses the image's exact type (e.g. HEIC, JPEG)
    /// so the saved file keeps the right extension.
    private static func firstReceiptAttachment(in context: NSExtensionContext?) throws -> Attachment {
        let items = context?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        for provider in items.flatMap({ $0.attachments ?? [] }) {
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                return Attachment(provider: provider, type: .pdf)
            }
            let imageType = provider.registeredTypeIdentifiers
                .compactMap { UTType($0) }
                .first { $0.conforms(to: .image) }
            if let imageType {
                return Attachment(provider: provider, type: imageType)
            }
        }
        throw ShareError.notAReceipt
    }

    /// Copies the file into the inbox. Falls back to the raw data for apps that don't offer a file.
    private static func save(_ attachment: Attachment, to store: ReceiptInboxStore) async throws {
        let fileExtension = attachment.type.preferredFilenameExtension
            ?? (attachment.type.conforms(to: .pdf) ? "pdf" : "jpg")
        let originalFileName = Self.originalFileName(for: attachment, fileExtension: fileExtension)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                _ = attachment.provider.loadFileRepresentation(forTypeIdentifier: attachment.type.identifier) { url, error in
                    // The file at `url` is deleted when this handler returns, so copy it here.
                    guard let url else {
                        continuation.resume(throwing: error ?? ShareError.unreadable)
                        return
                    }
                    do {
                        try store.addReceipt(copyingFileAt: url, fileExtension: fileExtension, originalFileName: originalFileName)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                _ = attachment.provider.loadDataRepresentation(forTypeIdentifier: attachment.type.identifier) { data, error in
                    if let data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: error ?? ShareError.unreadable)
                    }
                }
            }
            try store.addReceipt(data: data, fileExtension: fileExtension, originalFileName: originalFileName)
        }
    }

    /// The name the shopper will recognise in Unfiled Receipts, e.g. "Invoice 1042.pdf" or "IMG_2231.heic".
    private static func originalFileName(for attachment: Attachment, fileExtension: String) -> String {
        let fallback = attachment.type.conforms(to: .pdf) ? "Receipt" : "Receipt photo"
        let name = attachment.provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = name.isEmpty ? fallback : name
        return (base as NSString).pathExtension.lowercased() == fileExtension.lowercased() ? base : "\(base).\(fileExtension)"
    }
}

enum ShareError: LocalizedError {
    case notAReceipt
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notAReceipt: "This isn't a photo or PDF."
        case .unreadable: "This receipt couldn't be read."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAReceipt: "Share a photo or PDF of your receipt to save it to Receipt Vault."
        case .unreadable: "Save it to Photos or Files first, then share it from there."
        }
    }
}
