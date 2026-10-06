import Foundation

/// Links into the app, e.g. from the widget. The app registers the "receiptvault" URL scheme.
enum AppLink: Equatable {
    case expiringSoon

    static let scheme = "receiptvault"

    /// receiptvault://expiring
    var url: URL {
        switch self {
        case .expiringSoon: URL(string: "\(Self.scheme)://expiring")!
        }
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        switch url.host?.lowercased() {
        case "expiring": self = .expiringSoon
        default: return nil
        }
    }
}
