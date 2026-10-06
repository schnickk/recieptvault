import Foundation

/// A claim the shopper has lodged against one warranty.
struct WarrantyClaim: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var lodgedOn: Date
    var faultDescription: String
    var status: ClaimStatus

    init(id: UUID = UUID(), lodgedOn: Date, faultDescription: String, status: ClaimStatus = .lodged) {
        self.id = id
        self.lodgedOn = lodgedOn
        self.faultDescription = faultDescription
        self.status = status
    }

    var isOpen: Bool { status.isOpen }
}
