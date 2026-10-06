import Foundation

/// An alert ready to show the shopper: what happened (title) and what to do next (message).
struct ShopperAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    /// Uses the error's errorDescription as the title and recoverySuggestion as the message.
    /// Errors that don't carry shopper wording, such as a storage failure, fall back to the text given.
    init(_ error: Error, fallbackTitle: String, fallbackMessage: String = "Please try again in a moment.") {
        let localized = error as? LocalizedError
        title = localized?.errorDescription ?? fallbackTitle
        message = localized?.recoverySuggestion ?? fallbackMessage
    }
}
