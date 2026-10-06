import SwiftUI

struct ExpiringSoonView: View {
    @Bindable var viewModel: ExpiringSoonViewModel
    let purchaseList: PurchaseListViewModel
    let factory: any ViewModelFactory

    var body: some View {
        NavigationStack {
            List(viewModel.warranties) { item in
                NavigationLink(value: PurchaseRoute(purchaseID: item.purchaseID)) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.itemName)
                                .font(.headline)
                            Text("\(item.warranty.kind.displayName) · \(item.retailer)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Ends \(item.warranty.expiryDate.formatted(date: .long, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        StatusPill(
                            title: viewModel.daysLeftLabel(for: item),
                            systemImage: "clock.badge.exclamationmark",
                            tint: .orange
                        )
                    }
                    .padding(.vertical, 2)
                }
            }
            .overlay {
                if viewModel.hasLoaded && viewModel.warranties.isEmpty {
                    ContentUnavailableView {
                        Label("No warranties ending in the next 30 days", systemImage: "checkmark.shield")
                    } description: {
                        Text("Warranties show up here a month before they end, so there's time to lodge a claim.")
                    }
                }
            }
            .navigationTitle("Expiring Soon")
            .navigationDestination(for: PurchaseRoute.self) { route in
                PurchaseDetailView(purchaseID: route.purchaseID, purchaseList: purchaseList, factory: factory)
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .shopperAlert($viewModel.alert)
        }
    }
}

#Preview {
    PreviewHost { container, _ in
        ExpiringSoonView(
            viewModel: container.makeExpiringSoonViewModel(),
            purchaseList: container.makePurchaseListViewModel(),
            factory: container
        )
    }
}
