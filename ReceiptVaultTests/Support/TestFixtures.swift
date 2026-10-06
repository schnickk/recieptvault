import Foundation
import XCTest
@testable import ReceiptVault

/// A fixed "now" of 10am, 6 October 2026, so tests never depend on the real date.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "en_AU")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func startOfDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: date(year, month, day))
    }

    static let today = date(2026, 10, 6)
    static let yesterday = date(2026, 10, 5)
    static let tomorrow = date(2026, 10, 7)

    static let now: @Sendable () -> Date = { today }

    static func daysFromToday(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: today))!
    }
}

extension RecordPurchase.Request {
    static func headphones(
        purchasedOn purchaseDate: Date = TestClock.today,
        price: Decimal = 499,
        warranties: [RecordPurchase.WarrantyTerms] = [.init(kind: .manufacturer, lengthInMonths: 12)]
    ) -> Self {
        .init(
            itemName: "Noise-cancelling headphones",
            retailer: "JB Hi-Fi",
            purchaseDate: purchaseDate,
            price: price,
            category: .electronics,
            warranties: warranties
        )
    }
}

extension Purchase {
    static func fridge(receiptFileName: String? = nil, warranties: [Warranty] = []) -> Purchase {
        Purchase(
            itemName: "Fridge",
            retailer: "The Good Guys",
            purchaseDate: TestClock.date(2025, 3, 14),
            price: 1899,
            category: .appliances,
            receiptFileName: receiptFileName,
            warranties: warranties
        )
    }
}

extension Warranty {
    static func manufacturer(endingOn expiryDate: Date, claims: [WarrantyClaim] = []) -> Warranty {
        Warranty(kind: .manufacturer, lengthInMonths: 24, expiryDate: expiryDate, claims: claims)
    }
}

extension WarrantyClaim {
    static func claim(_ status: ClaimStatus, lodgedOn: Date = TestClock.date(2026, 9, 1)) -> WarrantyClaim {
        WarrantyClaim(lodgedOn: lodgedOn, faultDescription: "Door seal is split", status: status)
    }
}

extension UnfiledReceipt {
    static func sharedPDF() -> UnfiledReceipt {
        UnfiledReceipt(fileName: "8F3A-receipt.pdf", originalFileName: "JB Hi-Fi receipt.pdf", receivedAt: TestClock.yesterday)
    }
}

/// Asserts that `body` throws exactly `expected`.
func assertThrows<T, E: Error & Equatable>(
    _ expected: E,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> T
) async {
    do {
        _ = try await body()
        XCTFail("Expected \(expected), but nothing was thrown", file: file, line: line)
    } catch let error as E {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Expected \(expected), but got \(error)", file: file, line: line)
    }
}
