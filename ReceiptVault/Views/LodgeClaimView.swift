import SwiftUI

struct LodgeClaimView: View {
    @State private var viewModel: ClaimViewModel
    private let warranty: Warranty
    private let itemName: String
    private let onLodged: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(viewModel: ClaimViewModel, warranty: Warranty, itemName: String, onLodged: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.warranty = warranty
        self.itemName = itemName
        self.onLodged = onLodged
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Item", value: itemName)
                    LabeledContent("Warranty", value: warranty.kind.displayName)
                    LabeledContent("Lodged on", value: viewModel.lodgedOn.formatted(date: .long, time: .omitted))
                }

                Section {
                    TextField("What's wrong with it?", text: $viewModel.faultDescription, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("Fault description")
                } footer: {
                    Text("Describe the fault the way you'd explain it to the retailer, including when it started.")
                }
            }
            .navigationTitle("Lodge a Claim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lodge Claim") {
                        Task {
                            if await viewModel.lodgeClaim(onWarrantyWithID: warranty.id) {
                                onLodged()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canLodge)
                }
            }
            .interactiveDismissDisabled(viewModel.isWorking)
            .shopperAlert($viewModel.alert)
        }
    }
}

#Preview {
    PreviewHost { container, purchases in
        let purchase = purchases.first { $0.category == .appliances } ?? purchases[0]
        LodgeClaimView(
            viewModel: container.makeClaimViewModel(),
            warranty: purchase.warranties[0],
            itemName: purchase.itemName
        ) {}
    }
}
