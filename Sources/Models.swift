import Foundation

// MARK: - Symbol entry (symbol + its type, persisted)

struct SymbolEntry: Codable, Equatable {
    static let defaults = [
        // Stocks — US mega cap tech
        Self(symbol: "AAPL", quoteType: "EQUITY"),
        Self(symbol: "MSFT", quoteType: "EQUITY"),
        Self(symbol: "NVDA", quoteType: "EQUITY"),
        Self(symbol: "META", quoteType: "EQUITY"),
        Self(symbol: "GOOG", quoteType: "EQUITY"),
        // Stocks — AI & semis (strong YTD performers)
        Self(symbol: "PLTR", quoteType: "EQUITY"),  // Palantir — AI enterprise
        Self(symbol: "ARM", quoteType: "EQUITY"),   // Arm Holdings — chip architecture
        Self(symbol: "TSM", quoteType: "EQUITY"),   // TSMC — world's largest foundry
        Self(symbol: "AVGO", quoteType: "EQUITY"),  // Broadcom — AI networking
        // ETF — tech & growth
        Self(symbol: "QQQ", quoteType: "ETF"),      // NASDAQ-100 — top 100 tech companies
        Self(symbol: "SOXX", quoteType: "ETF"),     // Semiconductors (NVIDIA, AMD, TSMC…)
        Self(symbol: "SMH", quoteType: "ETF"),      // Semiconductors (VanEck)
        Self(symbol: "IGV", quoteType: "ETF"),      // Software companies (pure SaaS plays)
        Self(symbol: "XLK", quoteType: "ETF"),      // S&P 500 Tech sector
        Self(symbol: "SPY", quoteType: "ETF"),      // S&P 500 — broad US market pulse
        Self(symbol: "VGK", quoteType: "ETF"),      // European large caps (EU economy)
        // Markets — indices, forex
        Self(symbol: "EURUSD=X", quoteType: "CURRENCY"),
        Self(symbol: "^FCHI", quoteType: "INDEX"),      // CAC 40
        Self(symbol: "^GDAXI", quoteType: "INDEX"),     // DAX
        Self(symbol: "^STOXX50E", quoteType: "INDEX"),  // Euro Stoxx 50 — EU blue chips
        Self(symbol: "^GSPC", quoteType: "INDEX")       // S&P 500 index (not ETF)
    ]

    let symbol: String
    let quoteType: String

    /// Infer quoteType from symbol format when not known (legacy / manual entry)
    static func infer(symbol: String) -> String {
        if symbol.hasPrefix("^") { return "INDEX" }
        if symbol.hasSuffix("=X") { return "CURRENCY" }
        if symbol.contains("-") { return "CRYPTOCURRENCY" }
        return "EQUITY"
    }
}

// MARK: - Raw JSON structs from ticker-cli

struct TickerDaily: Decodable {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let currency: String
    let marketState: String
}

struct TickerRangePoint: Decodable {
    let date: String
    let close: Double
}

struct TickerRange: Decodable {
    let symbol: String
    let points: [TickerRangePoint]

    private var deduped: [TickerRangePoint] {
        var seen = Set<String>()
        return points.filter { seen.insert($0.date).inserted }
    }

    var ytdChangePercent: Double? {
        let pts = deduped
        guard let first = pts.first, let last = pts.last, first.close > 0 else { return nil }
        return (last.close - first.close) / first.close * 100
    }

    var weeklyChangePercent: Double? {
        let pts = deduped
        guard pts.count >= 6, let last = pts.last else { return nil }
        let weekAgo = pts[pts.count - 6]
        guard weekAgo.close > 0 else { return nil }
        return (last.close - weekAgo.close) / weekAgo.close * 100
    }

    var sparklineCloses: [Double] {
        Array(deduped.suffix(30)).map { $0.close }
    }
}

// MARK: - UI model

struct TickerQuote: Identifiable {
    let id: String
    let symbol: String
    let quoteType: String
    let displayName: String
    let price: Double
    let currency: String
    let marketState: String
    let dailyChangePercent: Double
    let weeklyChangePercent: Double?
    let ytdChangePercent: Double?
    let sparklineCloses: [Double]?

    static func make(
        from daily: TickerDaily,
        entry: SymbolEntry,
        weekly: Double?,
        ytd: Double?,
        sparkline: [Double]?
    ) -> Self {
        Self(
            id: daily.symbol,
            symbol: daily.symbol,
            quoteType: entry.quoteType,
            displayName: Self.displayNames[daily.symbol] ?? daily.symbol,
            price: daily.price,
            currency: daily.currency,
            marketState: daily.marketState,
            dailyChangePercent: daily.changePercent,
            weeklyChangePercent: weekly,
            ytdChangePercent: ytd,
            sparklineCloses: sparkline
        )
    }
}

// MARK: - Tabs

enum WidgetTab: String, CaseIterable {
    case stocks = "Stocks"
    case etf = "ETF"
    case markets = "Markets"  // Indices, Forex, Crypto, Futures

    func matches(_ quoteType: String) -> Bool {
        switch self {
        case .stocks: return quoteType == "EQUITY"

        case .etf: return quoteType == "ETF" || quoteType == "MUTUALFUND"

        case .markets: return !["EQUITY", "ETF", "MUTUALFUND", "FUTURE"].contains(quoteType)
        }
    }
}
