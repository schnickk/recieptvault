import SwiftUI

/// The three tabs. Opens on Unfiled Receipts when receipts are waiting to be filed.
struct RootView: View {
    enum Tab: Hashable {
        case myPurchases
        case expiringSoon
        case unfiledReceipts
    }

    private let container: AppContainer

    @State private var purchaseList: PurchaseListViewModel
    @State private var expiringSoon: ExpiringSoonViewModel
    @State private var unfiledReceipts: UnfiledReceiptsViewModel
    @State private var selectedTab: Tab = .myPurchases
    @State private var isReady = false
    /// Set when the app was opened from a link (e.g. the widget), so launch doesn't override that tab.
    @State private var openedFromLink = false
    @Environment(\.scenePhase) private var scenePhase

    init(container: AppContainer) {
        self.container = container
        _purchaseList = State(initialValue: container.makePurchaseListViewModel())
        _expiringSoon = State(initialValue: container.makeExpiringSoonViewModel())
        _unfiledReceipts = State(initialValue: container.makeUnfiledReceiptsViewModel())
    }

    var body: some View {
        Group {
            if isReady {
                tabs
            } else {
                ProgressView()
            }
        }
        .task {
            await container.prepareForLaunch()
            await unfiledReceipts.load()
            if unfiledReceipts.hasWaitingReceipts && !openedFromLink {
                selectedTab = .unfiledReceipts
            }
            isReady = true
        }
        .onOpenURL { url in
            guard let link = AppLink(url: url) else { return }
            openedFromLink = true
            switch link {
            case .expiringSoon:
                selectedTab = .expiringSoon
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Receipts can arrive from the Share Extension while the app is in the background.
            // Reload the inbox, and if new ones arrived, show them, just as at launch.
            if phase == .background { openedFromLink = false }
            guard phase == .active, isReady else { return }
            Task {
                let countBefore = unfiledReceipts.badgeCount
                await unfiledReceipts.load()
                if unfiledReceipts.badgeCount > countBefore && !openedFromLink {
                    selectedTab = .unfiledReceipts
                }
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            MyPurchasesView(viewModel: purchaseList, factory: container)
                .tabItem { Label("My Purchases", systemImage: "bag") }
                .tag(Tab.myPurchases)

            ExpiringSoonView(viewModel: expiringSoon, purchaseList: purchaseList, factory: container)
                .tabItem { Label("Expiring Soon", systemImage: "clock.badge.exclamationmark") }
                .tag(Tab.expiringSoon)

            UnfiledReceiptsView(viewModel: unfiledReceipts, factory: container)
                .tabItem { Label("Unfiled Receipts", systemImage: "tray.full") }
                .badge(unfiledReceipts.badgeCount)
                .tag(Tab.unfiledReceipts)
        }
    }
}

#Preview {
    RootView(container: .preview())
}
