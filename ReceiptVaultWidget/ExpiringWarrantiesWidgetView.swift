import SwiftUI
import WidgetKit

struct ExpiringWarrantiesWidgetView: View {
    let entry: ExpiringWarrantiesEntry

    @Environment(\.widgetFamily) private var family

    static let emptyMessage = "No warranties ending in the next 30 days"

    var body: some View {
        switch family {
        case .systemMedium:
            MediumView(items: Array(entry.itemsEndingSoon.prefix(3)))
        case .accessoryRectangular:
            LockScreenView(soonest: entry.itemsEndingSoon.first)
        default:
            SmallView(soonest: entry.itemsEndingSoon.first)
        }
    }
}

// MARK: - Small: the single soonest warranty, with a big day count

private struct SmallView: View {
    let soonest: (item: WarrantySnapshot.Item, daysLeft: Int)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Expiring Soon", systemImage: "clock.badge.exclamationmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)

            if let soonest {
                Spacer(minLength: 0)
                if soonest.daysLeft == 0 {
                    Text("Today")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Last day of cover")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(soonest.daysLeft)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(soonest.daysLeft == 1 ? "day left" : "days left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(soonest.item.itemName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(soonest.item.warrantyKind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Spacer(minLength: 0)
                EmptyStateView()
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Medium: up to three rows

private struct MediumView: View {
    let items: [(item: WarrantySnapshot.Item, daysLeft: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Expiring Soon", systemImage: "clock.badge.exclamationmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            if items.isEmpty {
                Spacer(minLength: 0)
                EmptyStateView()
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                ForEach(items, id: \.item.id) { row in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.item.itemName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("\(row.item.retailer) · \(row.item.warrantyKind.displayName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text(WarrantySnapshot.Item.daysLeftLabel(row.daysLeft))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Lock Screen: "Dishwasher · 9 days left"

private struct LockScreenView: View {
    let soonest: (item: WarrantySnapshot.Item, daysLeft: Int)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Expiring Soon", systemImage: "clock.badge.exclamationmark")
                .font(.headline)
                .widgetAccentable()
            if let soonest {
                Text("\(soonest.item.itemName) · \(WarrantySnapshot.Item.daysLeftLabel(soonest.daysLeft))")
                    .font(.body)
                    .lineLimit(2)
            } else {
                Text(ExpiringWarrantiesWidgetView.emptyMessage)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.shield")
                .font(.title2)
                .foregroundStyle(.green)
            Text(ExpiringWarrantiesWidgetView.emptyMessage)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}
