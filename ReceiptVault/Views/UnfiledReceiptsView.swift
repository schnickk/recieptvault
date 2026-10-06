import SwiftUI

struct UnfiledReceiptsView: View {
    @Bindable var viewModel: UnfiledReceiptsViewModel
    let factory: any ViewModelFactory

    @State private var receiptToFile: UnfiledReceipt?

    var body: some View {
        NavigationStack {
            List(viewModel.receipts) { receipt in
                Button {
                    receiptToFile = receipt
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(receipt.originalFileName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Received \(receipt.receivedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("File")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        Task { await viewModel.remove(receipt) }
                    }
                }
            }
            .overlay {
                if viewModel.hasLoaded && viewModel.receipts.isEmpty {
                    ContentUnavailableView {
                        Label("No unfiled receipts", systemImage: "tray")
                    } description: {
                        Text("Receipts you share from Mail, Photos or Files wait here until you file them with a purchase.")
                    }
                }
            }
            .navigationTitle("Unfiled Receipts")
            .sheet(item: $receiptToFile) { receipt in
                AddPurchaseView(viewModel: factory.makeAddPurchaseViewModel(filing: receipt)) {
                    Task { await viewModel.load() }
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .shopperAlert($viewModel.alert)
        }
    }
}

#Preview {
    PreviewHost { container, _ in
        UnfiledReceiptsView(viewModel: container.makeUnfiledReceiptsViewModel(), factory: container)
    }
}
