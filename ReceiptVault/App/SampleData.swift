#if DEBUG
import UIKit

/// Realistic Australian purchases for development and demos. Compiled into DEBUG builds only.
///
/// Everything goes through the real use cases: RecordPurchase works out expiry dates,
/// FileSharedReceipt files the JB Hi-Fi receipt, and LodgeWarrantyClaim lodges the open claim.
/// No rule is bypassed. Receipt files are written to the App Group's ReceiptInbox folder.
enum SampleData {
    private static let didSeedKey = "SampleData.didSeed"

    /// Seeds once per install. After that, deleting every purchase leaves the list empty
    /// instead of bringing the samples back.
    static func seedOnFirstLaunch(using container: AppContainer, defaults: UserDefaults = .standard) async {
        guard !defaults.bool(forKey: didSeedKey) else { return }
        if await seedIfStoreIsEmpty(using: container) {
            defaults.set(true, forKey: didSeedKey)
        }
    }

    /// Returns true when the store ends up holding purchases, whether or not this call added them.
    @discardableResult
    static func seedIfStoreIsEmpty(using container: AppContainer) async -> Bool {
        do {
            guard try await container.purchaseRepository.fetchAllPurchases().isEmpty else { return true }
            try await seed(using: container)
            return true
        } catch {
            print("Sample purchases weren't added: \(error.localizedDescription)")
            return false
        }
    }

    private static func seed(using container: AppContainer) async throws {
        let calendar = container.calendar
        let now = container.now()
        let today = calendar.startOfDay(for: now)

        func monthsAgo(_ months: Int) -> Date {
            calendar.date(byAdding: .month, value: -months, to: today)!
        }

        /// A purchase date that makes a warranty of `months` end roughly `days` from today.
        func purchaseDate(warrantyMonths months: Int, endingInDays days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: monthsAgo(months))!
        }

        // 1. Manufacturer warranty ending within 30 days. Its receipt is filed through FileSharedReceipt.
        // Without the App Group there's nowhere to keep receipt files, so it's recorded without one.
        let headphonesDate = purchaseDate(warrantyMonths: 12, endingInDays: 9)
        let headphones = RecordPurchase.Request(
            itemName: "Sony WH-1000XM5 headphones",
            retailer: "JB Hi-Fi",
            purchaseDate: headphonesDate,
            price: Decimal(string: "549.00")!,
            category: .electronics,
            warranties: [.init(kind: .manufacturer, lengthInMonths: 12)]
        )
        if let headphonesReceipt = try await addUnfiledReceipt(
            retailer: "JB Hi-Fi",
            item: "Sony WH-1000XM5 headphones",
            price: "549.00",
            date: headphonesDate,
            originalFileName: "JB Hi-Fi receipt.pdf",
            receivedAt: headphonesDate,
            to: container
        ) {
            try await container.fileSharedReceipt.execute(receiptID: headphonesReceipt.id, into: .newPurchase(headphones))
        } else {
            try await container.recordPurchase.execute(headphones)
        }

        // 2. Second manufacturer warranty ending within 30 days.
        try await container.recordPurchase.execute(.init(
            itemName: "Dyson V15 Detect vacuum",
            retailer: "Harvey Norman",
            purchaseDate: purchaseDate(warrantyMonths: 24, endingInDays: 23),
            price: Decimal(string: "1249.00")!,
            category: .appliances,
            warranties: [.init(kind: .manufacturer, lengthInMonths: 24)]
        ))

        // 3. Manufacturer warranty plus an extended warranty.
        try await container.recordPurchase.execute(.init(
            itemName: "Samsung 65\" QLED TV",
            retailer: "The Good Guys",
            purchaseDate: monthsAgo(7),
            price: Decimal(string: "1995.00")!,
            category: .electronics,
            warranties: [
                .init(kind: .manufacturer, lengthInMonths: 12),
                .init(kind: .extended, lengthInMonths: 48),
            ]
        ))

        // 4. Active warranty with an open claim.
        let iPad = try await container.recordPurchase.execute(.init(
            itemName: "iPad Air 11-inch",
            retailer: "Apple",
            purchaseDate: monthsAgo(3),
            price: Decimal(string: "999.00")!,
            category: .electronics,
            warranties: [.init(kind: .manufacturer, lengthInMonths: 12)]
        ))
        try await container.lodgeWarrantyClaim.execute(
            warrantyID: iPad.warranties[0].id,
            faultDescription: "Screen flickers when brightness is below 30%."
        )

        // 5. Manufacturer warranty that has already ended.
        try await container.recordPurchase.execute(.init(
            itemName: "Ozito 18V cordless drill kit",
            retailer: "Bunnings",
            purchaseDate: monthsAgo(40),
            price: Decimal(string: "159.00")!,
            category: .tools,
            warranties: [.init(kind: .manufacturer, lengthInMonths: 36)]
        ))

        // A receipt left waiting in Unfiled Receipts, so the tab badge has something to count.
        let espressoDate = calendar.date(byAdding: .day, value: -1, to: today)!
        try await addUnfiledReceipt(
            retailer: "Myer",
            item: "Breville Barista Express",
            price: "899.00",
            date: espressoDate,
            originalFileName: "Myer receipt.pdf",
            receivedAt: now,
            to: container
        )
    }

    @discardableResult
    private static func addUnfiledReceipt(
        retailer: String,
        item: String,
        price: String,
        date: Date,
        originalFileName: String,
        receivedAt: Date,
        to container: AppContainer
    ) async throws -> UnfiledReceipt? {
        guard let sharedContainer = container.sharedContainer else { return nil }
        let pdf = receiptPDF(retailer: retailer, item: item, price: price, date: date)
        let fileName = try ReceiptInboxStore(container: sharedContainer).saveFile(pdf, fileExtension: "pdf")
        let receipt = UnfiledReceipt(fileName: fileName, originalFileName: originalFileName, receivedAt: receivedAt)
        try await container.receiptInbox.add(receipt)
        return receipt
    }

    /// A simple one-page tax invoice, so QuickLook has a real PDF to show.
    private static func receiptPDF(retailer: String, item: String, price: String, date: Date) -> Data {
        let width = 34
        func line(_ left: String, _ right: String) -> String {
            let space = max(1, width - left.count - right.count)
            return left + String(repeating: " ", count: space) + right
        }
        let total = Decimal(string: price)!
        let gst = (total / 11 as NSDecimalNumber).rounding(accordingToBehavior: nil)
        let rule = String(repeating: "-", count: width)
        let text = [
            retailer.uppercased(),
            "TAX INVOICE",
            date.formatted(date: .long, time: .omitted),
            rule,
            item,
            line("1 x", "$\(price)"),
            rule,
            line("TOTAL", "$\(price)"),
            line("GST included", "$\(gst.decimalValue.formatted(.number.precision(.fractionLength(2))))"),
            "",
            "Keep this receipt as proof",
            "of purchase.",
        ].joined(separator: "\n")

        let page = CGRect(x: 0, y: 0, width: 300, height: 400)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()
            (text as NSString).draw(
                in: page.insetBy(dx: 24, dy: 24),
                withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
            )
        }
    }
}
#endif
