import SwiftUI

struct SearchResultRow: View {
    let result: TickerSearchResult
    let alreadyAdded: Bool
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(result.symbol)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.semibold)
                    typeBadge
                    Text(result.exchangeName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Text(result.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if alreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green.opacity(0.6))
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(isHovered ? Color.accentColor : Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .help(Labels.quoteTypeDescription(result.quoteType))
        .onHover { inside in
            isHovered = inside
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture { if !alreadyAdded { onAdd() } }
    }

    private var typeBadge: some View {
        Text(result.typeLabel)
            .font(.system(size: 9))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill(badgeColor.opacity(0.12)))
    }

    private var badgeColor: Color {
        switch result.quoteType {
        case "CRYPTOCURRENCY": return .orange
        case "INDEX": return .purple
        case "ETF": return .blue
        case "CURRENCY": return .teal
        default: return .secondary
        }
    }
}
