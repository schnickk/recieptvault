import SwiftUI

/// Records a purchase by hand, or files an unfiled receipt against a new purchase.
struct AddPurchaseView: View {
    @State private var viewModel: AddPurchaseViewModel
    private let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field { case itemName, retailer, price }

    init(viewModel: AddPurchaseViewModel, onSaved: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                if let receipt = viewModel.receipt {
                    Section {
                        Label(receipt.originalFileName, systemImage: "doc.text")
                    } header: {
                        Text("Receipt")
                    } footer: {
                        Text("This receipt will be filed with the new purchase.")
                    }
                }

                Section("Purchase") {
                    TextField("Item name", text: $viewModel.itemName)
                        .focused($focusedField, equals: .itemName)
                        .textInputAutocapitalization(.words)
                    TextField("Retailer", text: $viewModel.retailer)
                        .focused($focusedField, equals: .retailer)
                        .textInputAutocapitalization(.words)
                    DatePicker(
                        "Purchase date",
                        selection: $viewModel.purchaseDate,
                        in: ...viewModel.latestPurchaseDate,
                        displayedComponents: .date
                    )
                    LabeledContent("Price (AUD)") {
                        TextField("$0.00", text: $viewModel.priceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .price)
                    }
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(PurchaseCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }

                Section {
                    Stepper(
                        "Manufacturer warranty: \(monthsText(viewModel.manufacturerWarrantyMonths))",
                        value: $viewModel.manufacturerWarrantyMonths,
                        in: Warranty.allowedLengthInMonths
                    )
                    Toggle("Extended warranty", isOn: $viewModel.includesExtendedWarranty.animation())
                    if viewModel.includesExtendedWarranty {
                        Stepper(
                            "Extended warranty: \(monthsText(viewModel.extendedWarrantyMonths))",
                            value: $viewModel.extendedWarrantyMonths,
                            in: Warranty.allowedLengthInMonths
                        )
                    }
                } header: {
                    Text("Warranties")
                } footer: {
                    Text("Check the warranty card or the retailer's website. Each warranty can be up to 120 months (10 years).")
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.receipt == nil ? "Save" : "File Receipt") {
                        focusedField = nil
                        Task {
                            if await viewModel.save() {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .shopperAlert($viewModel.alert)
        }
    }

    private func monthsText(_ months: Int) -> String {
        months == 1 ? "1 month" : "\(months) months"
    }
}

#Preview("Add purchase") {
    PreviewHost { container, _ in
        AddPurchaseView(viewModel: container.makeAddPurchaseViewModel(filing: nil)) {}
    }
}

#Preview("File receipt") {
    PreviewHost { container, _ in
        AddPurchaseView(
            viewModel: container.makeAddPurchaseViewModel(
                filing: UnfiledReceipt(fileName: "preview.pdf", originalFileName: "Myer receipt.pdf", receivedAt: .now)
            )
        ) {}
    }
}
