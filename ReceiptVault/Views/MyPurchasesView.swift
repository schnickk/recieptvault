import SwiftUI

struct MyPurchasesView: View {
    @Bindable var viewModel: PurchaseListViewModel
    let factory: any ViewModelFactory

    @State private var isAddingPurchase = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sections) { section in
                    Section(section.title) {
                        ForEach(section.purchases) { purchase in
                            NavigationLink(value: PurchaseRoute(purchaseID: purchase.id)) {
                                PurchaseRow(purchase: purchase, status: viewModel.status(of: purchase))
                            }
                        }
                    }
                }
            }
            .overlay {
                if viewModel.hasLoaded && viewModel.purchases.isEmpty {
                    ContentUnavailableView {
                        Label("No purchases yet", systemImage: "bag")
                    } description: {
                        Text("Share a receipt from Mail or Photos, or tap + to add one.")
                    }
                }
            }
            .navigationTitle("My Purchases")
            .navigationDestination(for: PurchaseRoute.self) { route in
                PurchaseDetailView(purchaseID: route.purchaseID, purchaseList: viewModel, factory: factory)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Purchase", systemImage: "plus") {
                        isAddingPurchase = true
                    }
                }
            }
            .sheet(isPresented: $isAddingPurchase) {
                AddPurchaseView(viewModel: factory.makeAddPurchaseViewModel(filing: nil)) {
                    Task { await viewModel.load() }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .shopperAlert($viewModel.alert)
        }
    }
}

private struct PurchaseRow: View {
    let purchase: Purchase
    let status: WarrantyStatus

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(purchase.itemName)
                    .font(.headline)
                Text(purchase.retailer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            StatusPill(status)
        }
        .padding(.vertical, 2)
    }
}

#Preview("Sample purchases") {
    PreviewHost { container, _ in
        MyPurchasesView(viewModel: container.makePurchaseListViewModel(), factory: container)
    }
}

#Preview("No purchases yet") {
    let container = AppContainer(
        purchaseRepository: CoreDataPurchaseRepository(container: PersistenceController(inMemory: true).container),
        receiptInbox: InMemoryReceiptInbox(),
        snapshotPublisher: InMemoryWarrantySnapshotPublisher()
    )
    return MyPurchasesView(viewModel: container.makePurchaseListViewModel(), factory: container)
}
