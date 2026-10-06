import SwiftUI

extension View {
    /// Shows a ShopperAlert: errorDescription as the title, recoverySuggestion as the message.
    func shopperAlert(_ alert: Binding<ShopperAlert?>) -> some View {
        self.alert(
            alert.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { alert.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented { alert.wrappedValue = nil }
                }
            ),
            presenting: alert.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { shown in
            Text(shown.message)
        }
    }
}
