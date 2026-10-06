import Foundation

extension Date {
    /// The long Australian date used in messages to the shopper, e.g. "6 October 2026".
    var shopperFormatted: String {
        formatted(Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: "en_AU"), timeZone: .current))
    }
}
