import SwiftUI

/// A small capsule with an SF Symbol and a label, tinted by meaning.
struct StatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
            .fixedSize()
            .accessibilityElement(children: .combine)
    }
}

extension StatusPill {
    init(_ status: WarrantyStatus) {
        switch status {
        case .active:
            self.init(title: status.label, systemImage: "checkmark.shield", tint: .green)
        case .endingSoon:
            self.init(title: status.label, systemImage: "clock.badge.exclamationmark", tint: .orange)
        case .ended:
            self.init(title: status.label, systemImage: "shield.slash", tint: .secondary)
        case .noWarranty:
            self.init(title: status.label, systemImage: "minus.circle", tint: .secondary)
        }
    }

    init(_ status: ClaimStatus) {
        switch status {
        case .lodged:
            self.init(title: status.displayName, systemImage: "paperplane", tint: .blue)
        case .inProgress:
            self.init(title: status.displayName, systemImage: "wrench.and.screwdriver", tint: .orange)
        case .resolved:
            self.init(title: status.displayName, systemImage: "checkmark.circle", tint: .green)
        case .rejected:
            self.init(title: status.displayName, systemImage: "xmark.circle", tint: .red)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        StatusPill(WarrantyStatus.active(daysRemaining: 200))
        StatusPill(WarrantyStatus.endingSoon(daysRemaining: 9))
        StatusPill(WarrantyStatus.ended(kind: .manufacturer, endedOn: .now))
        StatusPill(ClaimStatus.lodged)
        StatusPill(ClaimStatus.resolved)
    }
    .padding()
}
