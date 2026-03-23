import Foundation

// Raw JSON structs from ticker-cli --format json --compact
struct TickerDaily: Decodable {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let currency: String
    let marketState: String
}

struct TickerPeriod: Decodable {
    let symbol: String
    let changePercent: Double
    let period: String
}

// Merged model used in UI
struct TickerQuote: Identifiable {
    static let names: [String: String] = [
        "AAPL": "Apple",
        "MSFT": "Microsoft",
        "NVDA": "Nvidia",
        "META": "Meta",
        "GOOG": "Alphabet",
        "EURUSD=X": "EUR/USD",
        "^FCHI": "CAC 40",
        "^GDAXI": "DAX"
    ]

    let id: String
    let symbol: String
    let displayName: String
    let price: Double
    let currency: String
    let marketState: String
    let dailyChangePercent: Double
    let weeklyChangePercent: Double?
    let ytdChangePercent: Double?

    static func make(
        from daily: TickerDaily,
        weekly: Double?,
        ytd: Double?
    ) -> Self {
        Self(
            id: daily.symbol,
            symbol: daily.symbol,
            displayName: Self.names[daily.symbol] ?? daily.symbol,
            price: daily.price,
            currency: daily.currency,
            marketState: daily.marketState,
            dailyChangePercent: daily.changePercent,
            weeklyChangePercent: weekly,
            ytdChangePercent: ytd
        )
    }
}

let defaultSymbols = ["AAPL", "MSFT", "NVDA", "META", "GOOG", "EURUSD=X", "^FCHI", "^GDAXI"]
