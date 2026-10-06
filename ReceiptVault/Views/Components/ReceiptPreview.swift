import QuickLook
import QuickLookThumbnailing
import SwiftUI

/// A thumbnail of a receipt file (PDF or image). Tapping it opens the full QuickLook preview.
struct ReceiptPreview: View {
    let url: URL

    @Environment(\.displayScale) private var displayScale
    @State private var thumbnail: UIImage?
    @State private var quickLookURL: URL?

    var body: some View {
        Button {
            quickLookURL = url
        } label: {
            VStack(spacing: 8) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(radius: 1)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 220)

                Label("View receipt", systemImage: "eye")
                    .font(.subheadline)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("View receipt")
        .quickLookPreview($quickLookURL)
        .task(id: url) {
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 240, height: 320),
                scale: displayScale,
                representationTypes: .thumbnail
            )
            thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).uiImage
        }
    }
}
