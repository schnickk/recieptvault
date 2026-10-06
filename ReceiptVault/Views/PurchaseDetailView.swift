import SwiftUI

struct PurchaseDetailView: View {
    let purchaseID: UUID
    let purchaseList: PurchaseListViewModel
    let factory: any ViewModelFactory

    @State private var claims: ClaimViewModel
    @State private var warrantyForNewClaim: Warranty?

    init(purchaseID: UUID, purchaseList: PurchaseListViewModel, factory: any ViewModelFactory) {
        self.purchaseID = purchaseID
        self.purchaseList = purchaseList
        self.factory = factory
        _claims = State(initialValue: factory.makeClaimViewModel())
    }

    private var purchase: Purchase? { purchaseList.purchase(withID: purchaseID) }

    var body: some View {
        Group {
            if let purchase {
                details(of: purchase)
            } else if purchaseList.hasLoaded {
                ContentUnavailableView(
                    "Purchase not found",
                    systemImage: "bag",
                    description: Text("It may have been deleted. Go back to My Purchases.")
                )
            } else {
                ProgressView()
            }
        }
        .task {
            if purchase == nil { await purchaseList.load() }
        }
        .sheet(item: $warrantyForNewClaim) { warranty in
            LodgeClaimView(
                viewModel: factory.makeClaimViewModel(),
                warranty: warranty,
                itemName: purchase?.itemName ?? ""
            ) {
                Task { await purchaseList.load() }
            }
        }
        .shopperAlert($claims.alert)
    }

    private func details(of purchase: Purchase) -> some View {
        List {
            Section("Purchase") {
                LabeledContent("Retailer", value: purchase.retailer)
                LabeledContent("Purchase date", value: purchase.purchaseDate.formatted(date: .long, time: .omitted))
                LabeledContent("Price", value: purchase.price.formatted(.currency(code: "AUD")))
                LabeledContent("Category", value: purchase.category.displayName)
            }

            Section("Receipt") {
                if let url = purchaseList.receiptURL(for: purchase) {
                    ReceiptPreview(url: url)
                } else if purchase.hasReceipt {
                    Label("This receipt can't be found on this device.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    Label("No receipt filed", systemImage: "doc")
                        .foregroundStyle(.secondary)
                }
            }

            if purchase.warranties.isEmpty {
                Section("Warranty") {
                    Text("No warranty recorded for this purchase.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(purchase.warranties) { warranty in
                warrantySection(warranty)
            }
        }
        .navigationTitle(purchase.itemName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await purchaseList.load() }
    }

    private func warrantySection(_ warranty: Warranty) -> some View {
        let status = purchaseList.status(of: warranty)
        return Section {
            HStack {
                StatusPill(status)
                Spacer()
                if let daysLeft = status.daysLeftLabel {
                    Text(daysLeft)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Length", value: "\(warranty.lengthInMonths) months")
            LabeledContent(
                status.daysLeftLabel == nil ? "Ended on" : "Ends on",
                value: warranty.expiryDate.formatted(date: .long, time: .omitted)
            )

            ForEach(warranty.claims) { claim in
                ClaimRow(claim: claim, isWorking: claims.isWorking) { outcome in
                    Task {
                        if await claims.markClaim(withID: claim.id, as: outcome) {
                            await purchaseList.load()
                        }
                    }
                }
            }

            if purchaseList.canLodgeClaim(on: warranty) {
                Button("Lodge a claim", systemImage: "exclamationmark.bubble") {
                    warrantyForNewClaim = warranty
                }
            }
        } header: {
            Text(warranty.kind.displayName)
        } footer: {
            if case .ended = status {
                Text(ConsumerLaw.advice)
            } else if warranty.hasOpenClaim {
                Text("Mark the open claim resolved or rejected before lodging another.")
            }
        }
    }
}

private struct ClaimRow: View {
    let claim: WarrantyClaim
    let isWorking: Bool
    let onMark: (ResolveClaim.Outcome) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Claim lodged \(claim.lodgedOn.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusPill(claim.status)
            }
            Text(claim.faultDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if claim.isOpen {
                HStack(spacing: 20) {
                    Button("Mark resolved", systemImage: "checkmark.circle") { onMark(.resolved) }
                    Button("Mark rejected", systemImage: "xmark.circle", role: .destructive) { onMark(.rejected) }
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
                .disabled(isWorking)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Open claim and receipt") {
    PreviewHost { container, purchases in
        let purchaseList = container.makePurchaseListViewModel()
        let purchase = purchases.first { $0.warranties.contains(where: \.hasOpenClaim) } ?? purchases[0]
        NavigationStack {
            PurchaseDetailView(purchaseID: purchase.id, purchaseList: purchaseList, factory: container)
        }
    }
}

#Preview("Warranty ended") {
    PreviewHost { container, purchases in
        let purchaseList = container.makePurchaseListViewModel()
        let purchase = purchases.first { $0.category == .tools } ?? purchases[0]
        NavigationStack {
            PurchaseDetailView(purchaseID: purchase.id, purchaseList: purchaseList, factory: container)
        }
    }
}
