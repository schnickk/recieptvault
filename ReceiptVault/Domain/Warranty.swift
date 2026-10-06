import Foundation

/// Warranty cover attached to a purchase.
struct Warranty: Identifiable, Hashable, Codable, Sendable {
    /// The longest warranty Receipt Vault accepts: 10 years.
    static let allowedLengthInMonths = 0...120

    let id: UUID
    var kind: WarrantyKind
    var lengthInMonths: Int
    /// The last day of cover. Stored rather than recalculated, and only RecordPurchase works it out.
    let expiryDate: Date
    var claims: [WarrantyClaim]

    init(id: UUID = UUID(), kind: WarrantyKind, lengthInMonths: Int, expiryDate: Date, claims: [WarrantyClaim] = []) {
        self.id = id
        self.kind = kind
        self.lengthInMonths = lengthInMonths
        self.expiryDate = expiryDate
        self.claims = claims
    }

    /// True up to and including the whole of the expiry day.
    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) <= calendar.startOfDay(for: expiryDate)
    }

    func hasEnded(on date: Date, calendar: Calendar = .current) -> Bool {
        !isActive(on: date, calendar: calendar)
    }

    /// Whole calendar days from `date` to the expiry day: 0 on the expiry day, negative once ended.
    func daysRemaining(from date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: expiryDate)
        ).day ?? 0
    }

    var openClaim: WarrantyClaim? { claims.first(where: \.isOpen) }

    var hasOpenClaim: Bool { openClaim != nil }
}
