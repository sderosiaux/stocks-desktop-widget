import SwiftUI

struct TickerRow: View {
    let ticker: TickerQuote
    let onRemove: () -> Void

    @State private var isHovered = false
    @State private var showHoldings = false
    @State private var holdings: [ETFHolding] = []
    @State private var isLoadingHoldings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                removeOrDot
                Text(primaryLabel)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                Spacer()
                Text(priceString)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                if ticker.quoteType == "ETF" && isHovered {
                    etfInfoButton
                }
            }
            HStack(spacing: 6) {
                Text(secondaryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                sparklineView
                trendText(ticker.dailyChangePercent, tooltip: "Today")
                Text("·").font(.system(size: 9)).foregroundStyle(.tertiary)
                if let weekly = ticker.weeklyChangePercent {
                    trendText(weekly, tooltip: "This week")
                    Text("·").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                if let ytd = ticker.ytdChangePercent {
                    trendText(ytd, tooltip: "Year to date")
                }
            }
            .padding(.leading, 14)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = inside }
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture { openYahoo() }
    }

    // MARK: - ETF info button

    private var etfInfoButton: some View {
        Button {
            if holdings.isEmpty { Task { await loadHoldings() } }
            showHoldings.toggle()
        } label: {
            Image(systemName: "chart.pie")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showHoldings, arrowEdge: .trailing) {
            ETFHoldingsView(
                symbol: ticker.symbol,
                holdings: holdings,
                isLoading: isLoadingHoldings
            )
        }
        .help("Top holdings")
    }

    // MARK: - Remove / dot

    @ViewBuilder
    private var removeOrDot: some View {
        if isHovered {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.75))
            }
            .buttonStyle(.plain)
            .transition(.opacity.combined(with: .scale(scale: 0.7)))
        } else {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .padding(.trailing, 2)
                .help(Labels.marketStateDescription(ticker.marketState))
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
        }
    }

    // MARK: - Labels

    private var isForex: Bool { ticker.symbol.hasSuffix("=X") }
    private var isIndex: Bool { ticker.symbol.hasPrefix("^") }
    private var isETF: Bool { ticker.quoteType == "ETF" || ticker.quoteType == "MUTUALFUND" }

    /// Show friendly name for non-stock assets; raw symbol for stocks (AAPL, MSFT…)
    private var primaryLabel: String {
        isForex || isIndex || isETF ? ticker.displayName : ticker.symbol
    }

    /// Secondary: company name for stocks, symbol for ETF/index/forex
    private var secondaryLabel: String {
        if ticker.quoteType == "EQUITY" { return ticker.displayName }
        return ticker.symbol
    }

    // MARK: - Market dot

    private var dotColor: Color {
        switch ticker.marketState {
        case "REGULAR": return .green
        case "PRE", "POST", "PREPRE": return .yellow
        default: return Color.primary.opacity(0.2)
        }
    }

    // MARK: - Price

    @ViewBuilder
    private var sparklineView: some View {
        if let closes = ticker.sparklineCloses, closes.count >= 2 {
            GeometryReader { geo in
                sparklinePath(closes: closes, in: geo.size)
                    .stroke(sparklineColor(closes).opacity(0.75), lineWidth: 1)
            }
            .frame(width: 50, height: 14)
        }
    }

    private var priceString: String {
        if isForex {
            return String(format: "%.4f", ticker.price)
        } else if isIndex {
            return String(format: "%.0f", ticker.price)
        } else {
            return String(format: "$%.2f", ticker.price)
        }
    }

    private func sparklinePath(closes: [Double], in size: CGSize) -> Path {
        guard let minVal = closes.min(), let maxVal = closes.max() else { return Path() }
        let range = maxVal - minVal
        return Path { path in
            for (idx, close) in closes.enumerated() {
                let xFrac = CGFloat(idx) / CGFloat(closes.count - 1)
                let yFrac = range > 0 ? CGFloat((close - minVal) / range) : 0.5
                let point = CGPoint(x: size.width * xFrac, y: size.height * (1 - yFrac))
                if idx == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
    }

    private func sparklineColor(_ closes: [Double]) -> Color {
        guard let first = closes.first, let last = closes.last else { return .secondary }
        return last >= first ? .green : .red
    }

    private func trendText(_ pct: Double, tooltip: String) -> some View {
        let positive = pct >= 0
        return Text(String(format: "%+.2f%%", pct))
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(positive ? Color.green : Color.red)
            .help(tooltip)
    }

    private func loadHoldings() async {
        isLoadingHoldings = true
        holdings = await TickerService.fetchTopHoldings(symbol: ticker.symbol)
        isLoadingHoldings = false
    }

    private func openYahoo() {
        let encoded = ticker.symbol
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ticker.symbol
        guard let url = URL(string: "https://finance.yahoo.com/chart/\(encoded)?interval=1wk&range=1y") else { return }
        NSWorkspace.shared.open(url)
    }
}
