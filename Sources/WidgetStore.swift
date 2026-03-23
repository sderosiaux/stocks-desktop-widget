import Combine
import Foundation

final class WidgetStore: ObservableObject {
    @Published var tickers: [TickerQuote] = []
    @Published var lastRefresh: Date?
    @Published var isLoading = false

    let symbols: [String]

    init(symbols: [String] = defaultSymbols) {
        self.symbols = symbols
        // Show cached data immediately on startup
        if let cached = QuoteCache.load(maxAge: QuoteCache.dailyTTL) {
            tickers = cached
            lastRefresh = QuoteCache.cachedAt()
        }
    }

    @MainActor
    func refresh() async {
        // Skip if cache is still fresh (avoids hitting API on every timer tick
        // when the widget was just restored from background)
        if let cached = QuoteCache.load(maxAge: QuoteCache.dailyTTL), !tickers.isEmpty {
            tickers = cached
            lastRefresh = QuoteCache.cachedAt()
            return
        }

        isLoading = true
        let result = await Task.detached {
            TickerService.fetchQuotes(symbols: self.symbols)
        }.value
        if !result.isEmpty {
            QuoteCache.save(result)
            self.tickers = result
        }
        self.lastRefresh = Date()
        self.isLoading = false
    }

    @MainActor
    func forceRefresh() async {
        isLoading = true
        let result = await Task.detached {
            TickerService.fetchQuotes(symbols: self.symbols)
        }.value
        if !result.isEmpty {
            QuoteCache.save(result)
            self.tickers = result
        }
        self.lastRefresh = Date()
        self.isLoading = false
    }
}
