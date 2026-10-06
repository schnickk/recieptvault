import SwiftUI
import WidgetKit

/// Warranties ending in the next 30 days, read from the snapshot the app writes to the App Group.
struct ReceiptVaultWidget: Widget {
    let kind = "ExpiringWarranties"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpiringWarrantiesProvider()) { entry in
            ExpiringWarrantiesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(AppLink.expiringSoon.url)
        }
        .configurationDisplayName("Expiring Soon")
        .description("Warranties ending in the next 30 days, so you can lodge a claim in time.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct ExpiringWarrantiesEntry: TimelineEntry {
    /// The day being drawn. Days left are worked out from this, not from when the snapshot was saved.
    let date: Date
    let snapshot: WarrantySnapshot

    var itemsEndingSoon: [(item: WarrantySnapshot.Item, daysLeft: Int)] {
        snapshot.itemsEndingSoon(on: date)
    }
}

extension ExpiringWarrantiesEntry {
    /// A realistic example for the widget gallery and loading placeholder. Never "No data".
    static func sample(on date: Date = .now) -> ExpiringWarrantiesEntry {
        func item(_ name: String, _ retailer: String, _ kind: WarrantyKind, endingInDays days: Int) -> WarrantySnapshot.Item {
            let day = Calendar.current.startOfDay(for: date)
            return WarrantySnapshot.Item(
                id: UUID(),
                itemName: name,
                retailer: retailer,
                warrantyKind: kind,
                expiryDate: Calendar.current.date(byAdding: .day, value: days, to: day) ?? day
            )
        }
        return ExpiringWarrantiesEntry(
            date: date,
            snapshot: WarrantySnapshot(generatedAt: date, items: [
                item("Dishwasher", "Harvey Norman", .manufacturer, endingInDays: 9),
                item("Noise-cancelling headphones", "JB Hi-Fi", .manufacturer, endingInDays: 16),
                item("Cordless vacuum", "The Good Guys", .extended, endingInDays: 27),
            ])
        )
    }
}

struct ExpiringWarrantiesProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpiringWarrantiesEntry {
        .sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpiringWarrantiesEntry) -> Void) {
        completion(context.isPreview ? .sample() : ExpiringWarrantiesEntry(date: .now, snapshot: Self.loadSnapshot()))
    }

    /// One entry for now and one at the next midnight, so "N days left" ticks over at the start of
    /// each day. After midnight WidgetKit asks again and re-reads the file.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpiringWarrantiesEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let snapshot = Self.loadSnapshot()
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 60 * 60)

        completion(Timeline(
            entries: [
                ExpiringWarrantiesEntry(date: now, snapshot: snapshot),
                ExpiringWarrantiesEntry(date: nextMidnight, snapshot: snapshot),
            ],
            policy: .atEnd
        ))
    }

    /// A missing, unreadable or inaccessible snapshot shows the empty state. It never crashes.
    private static func loadSnapshot() -> WarrantySnapshot {
        guard let container = try? SharedContainer() else { return .empty }
        return WarrantySnapshotFile.read(from: container) ?? .empty
    }
}

#Preview("Small", as: .systemSmall) {
    ReceiptVaultWidget()
} timeline: {
    ExpiringWarrantiesEntry.sample()
    ExpiringWarrantiesEntry(date: .now, snapshot: .empty)
}

#Preview("Medium", as: .systemMedium) {
    ReceiptVaultWidget()
} timeline: {
    ExpiringWarrantiesEntry.sample()
    ExpiringWarrantiesEntry(date: .now, snapshot: .empty)
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    ReceiptVaultWidget()
} timeline: {
    ExpiringWarrantiesEntry.sample()
    ExpiringWarrantiesEntry(date: .now, snapshot: .empty)
}
