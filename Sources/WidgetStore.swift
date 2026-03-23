import Combine
import Foundation

final class WidgetStore: ObservableObject {
    @Published var tickers: [TickerQuote] = []
    @Published var entries: [SymbolEntry]
    @Published var activeTab: WidgetTab = .stocks
    @Published var lastRefresh: Date?
    @Published var isLoading = false
    @Published var isAdding = false
    @Published var addError: String?

    @Published var searchQuery: String = "" {
        didSet { scheduleSearch() }
    }
    @Published var searchResults: [TickerSearchResult] = []
    @Published var isSearching = false

    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    var visibleTickers: [TickerQuote] {
        tickers.filter { activeTab.matches($0.quoteType) }
    }

    init() {
        entries = SymbolStore.load() ?? SymbolEntry.defaults
        if let cached = QuoteCache.load(maxAge: QuoteCache.dailyTTL) {
            tickers = cached
            lastRefresh = QuoteCache.cachedAt()
        }
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        guard !searchQuery.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        let query = searchQuery
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = await TickerService.search(query: query)
            guard !Task.isCancelled else { return }
            searchResults = results
            isSearching = false
        }
    }

    // MARK: - Adaptive refresh loop

    func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                let interval = MarketCalendar.refreshInterval()
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }

    // MARK: - Refresh

    @MainActor
    func refresh() async {
        if let cached = QuoteCache.load(maxAge: QuoteCache.dailyTTL), !tickers.isEmpty {
            tickers = cached
            lastRefresh = QuoteCache.cachedAt()
            return
        }
        await fetchAndUpdate()
    }

    @MainActor
    func forceRefresh() async {
        await fetchAndUpdate()
    }

    @MainActor
    private func fetchAndUpdate() async {
        isLoading = true
        let currentEntries = entries
        let result = await Task.detached {
            TickerService.fetchQuotes(entries: currentEntries)
        }.value
        if !result.isEmpty {
            QuoteCache.save(result)
            tickers = result
        }
        lastRefresh = Date()
        isLoading = false
    }

    // MARK: - Add

    @MainActor
    func addTicker(symbol: String, quoteType: String) async {
        let alreadyExists = entries.contains { $0.symbol == symbol }
        guard !symbol.isEmpty, !alreadyExists else {
            addError = alreadyExists ? "\(symbol) already in list" : nil
            return
        }

        addError = nil
        isAdding = true

        let entry = SymbolEntry(symbol: symbol, quoteType: quoteType)
        let result = await Task.detached {
            TickerService.fetchQuotes(entries: [entry])
        }.value

        if let quote = result.first {
            entries.append(entry)
            SymbolStore.save(entries)
            tickers.append(quote)
            QuoteCache.save(tickers)
            activeTab = WidgetTab.allCases.first { $0.matches(quoteType) } ?? .stocks
        } else {
            addError = "'\(symbol)' not found"
        }

        isAdding = false
    }

    // MARK: - Remove

    func removeTicker(_ symbol: String) {
        entries.removeAll { $0.symbol == symbol }
        tickers.removeAll { $0.symbol == symbol }
        SymbolStore.save(entries)
        QuoteCache.save(tickers)
    }
}
