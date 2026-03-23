import SwiftUI

struct TickerRow: View {
    let ticker: TickerQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                marketDot
                Text(ticker.symbol)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                Spacer()
                Text(priceString)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                changeChip(ticker.dailyChangePercent, label: "1d")
            }
            HStack {
                Text(ticker.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let weekly = ticker.weeklyChangePercent {
                    changeChip(weekly, label: "1w")
                }
                if let y = ticker.ytdChangePercent {
                    changeChip(y, label: "YTD")
                }
            }
            .padding(.leading, 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var marketDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 6, height: 6)
            .padding(.trailing, 2)
    }

    private var dotColor: Color {
        switch ticker.marketState {
        case "REGULAR": return .green
        case "PRE", "POST": return .yellow
        default: return Color.primary.opacity(0.2)
        }
    }

    private var priceString: String {
        let isFX = ticker.symbol.hasSuffix("=X")
        let isIndex = ticker.symbol.hasPrefix("^")
        if isFX {
            return String(format: "%.4f", ticker.price)
        } else if isIndex {
            return String(format: "%.0f", ticker.price)
        } else {
            return String(format: "$%.2f", ticker.price)
        }
    }

    private func changeChip(_ pct: Double, label: String) -> some View {
        let positive = pct >= 0
        let text = String(format: "%@%.2f%%", positive ? "+" : "", pct)
        return Text("\(label): \(text)")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(positive ? Color.green : Color.red)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(positive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            )
    }
}
