import Observation
import SwiftUI

/// What the Share Extension is doing right now.
@MainActor
@Observable
final class ShareStatus {
    enum Phase {
        case saving
        case saved
        case failed(title: String, message: String)
    }

    var phase: Phase = .saving
}

struct ShareStatusView: View {
    let status: ShareStatus
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch status.phase {
            case .saving:
                ProgressView()
                    .controlSize(.large)
                Text("Saving receipt…")
                    .font(.headline)
                Button("Cancel", action: onClose)

            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Saved to Receipt Vault. Open the app to file it.")
                    .font(.headline)
                    .multilineTextAlignment(.center)

            case let .failed(title, message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Close", action: onClose)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .contain)
    }
}

#Preview("Saved") {
    let status = ShareStatus()
    status.phase = .saved
    return ShareStatusView(status: status) {}
}

#Preview("Failed") {
    let status = ShareStatus()
    status.phase = .failed(title: ShareError.notAReceipt.errorDescription!, message: ShareError.notAReceipt.recoverySuggestion!)
    return ShareStatusView(status: status) {}
}
