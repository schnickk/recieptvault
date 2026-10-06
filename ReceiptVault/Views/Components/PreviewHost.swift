import SwiftUI

/// Runs a preview against an in-memory store filled with the sample purchases.
/// It waits for the samples to be added, then hands over the container and the loaded purchases.
struct PreviewHost<Content: View>: View {
    @ViewBuilder let content: (AppContainer, [Purchase]) -> Content

    @State private var container = AppContainer.preview()
    @State private var purchases: [Purchase]?

    var body: some View {
        if let purchases {
            content(container, purchases)
        } else {
            ProgressView()
                .task {
                    await container.prepareForLaunch()
                    let list = container.makePurchaseListViewModel()
                    await list.load()
                    purchases = list.purchases
                }
        }
    }
}
