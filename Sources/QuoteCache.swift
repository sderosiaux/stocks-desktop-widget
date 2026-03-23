import Foundation

struct CachedQuotes: Codable {
    struct CachedQuote: Codable {
        let id: String
        let symbol: String
        let displayName: String
        let price: Double
        let currency: String
        let marketState: String
        let dailyChangePercent: Double
        let weeklyChangePercent: Double?
        let ytdChangePercent: Double?

        init(from ticker: TickerQuote) {
            id = ticker.id
            symbol = ticker.symbol
            displayName = ticker.displayName
            price = ticker.price
            currency = ticker.currency
            marketState = ticker.marketState
            dailyChangePercent = ticker.dailyChangePercent
            weeklyChangePercent = ticker.weeklyChangePercent
            ytdChangePercent = ticker.ytdChangePercent
        }

        func toTickerQuote() -> TickerQuote {
            TickerQuote(
                id: id,
                symbol: symbol,
                displayName: displayName,
                price: price,
                currency: currency,
                marketState: marketState,
                dailyChangePercent: dailyChangePercent,
                weeklyChangePercent: weeklyChangePercent,
                ytdChangePercent: ytdChangePercent
            )
        }
    }

    let quotes: [CachedQuote]
    let fetchedAt: Date
}

enum QuoteCache {
    // Daily prices: refresh matches widget interval (5 min)
    static let dailyTTL: TimeInterval = 5 * 60
    // Weekly/YTD: stable enough to cache for 1 hour
    static let extendedTTL: TimeInterval = 60 * 60

    private static var cacheDir: URL {
        let base: URL
        if let xdg = ProcessInfo.processInfo.environment["XDG_CACHE_HOME"] {
            base = URL(fileURLWithPath: xdg)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cache")
        }
        let dir = base.appendingPathComponent("stocks-widget")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var cacheFile: URL {
        cacheDir.appendingPathComponent("quotes.json")
    }

    static func load(maxAge: TimeInterval = dailyTTL) -> [TickerQuote]? {
        guard
            let data = try? Data(contentsOf: cacheFile),
            let cached = try? JSONDecoder().decode(CachedQuotes.self, from: data),
            Date().timeIntervalSince(cached.fetchedAt) < maxAge
        else { return nil }
        return cached.quotes.map { $0.toTickerQuote() }
    }

    static func save(_ quotes: [TickerQuote]) {
        let cached = CachedQuotes(
            quotes: quotes.map { CachedQuotes.CachedQuote(from: $0) },
            fetchedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: cacheFile)
    }

    static func cachedAt() -> Date? {
        guard
            let data = try? Data(contentsOf: cacheFile),
            let cached = try? JSONDecoder().decode(CachedQuotes.self, from: data)
        else { return nil }
        return cached.fetchedAt
    }
}
