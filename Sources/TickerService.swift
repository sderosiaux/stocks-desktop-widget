import Foundation

enum TickerService {
    private static let tickerCLI = "/Users/sderosiaux/go/bin/ticker-cli"
    private static let browserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
        + " AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    private static var cachedCrumb: String?

    private static func runCLI(_ args: [String]) -> Data? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let goBin = "\(homeDir)/go/bin"
        let pid = ProcessInfo.processInfo.processIdentifier
        let rand = Int.random(in: 0...999_999)
        let tmpFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("stocks-widget-\(pid)-\(rand).json")

        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "\(goBin):\(currentPath)"

        let cmd = ([tickerCLI] + args + [">", tmpFile.path]).joined(separator: " ")

        let process = Process()
        process.environment = env
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", cmd]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = try Data(contentsOf: tmpFile)
            try? FileManager.default.removeItem(at: tmpFile)
            return data
        } catch {
            try? FileManager.default.removeItem(at: tmpFile)
            return nil
        }
    }

    private static func parseCompactLines<T: Decodable>(_ data: Data, as type: T.Type) -> [T] {
        let lines = String(data: data, encoding: .utf8)?
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty } ?? []
        return lines.compactMap { line in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(T.self, from: lineData)
        }
    }

    // MARK: - Fetch quotes

    static func fetchQuotes(entries: [SymbolEntry]) -> [TickerQuote] {
        let symbols = entries.map { $0.symbol }
        let entryMap = Dictionary(uniqueKeysWithValues: entries.map { ($0.symbol, $0) })

        var daily: [TickerDaily] = []
        var ranges: [TickerRange] = []

        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            if let data = runCLI(symbols + ["--format", "json", "--compact"]) {
                daily = parseCompactLines(data, as: TickerDaily.self)
            }
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            if let data = runCLI(symbols + ["--range", "ytd", "--format", "json", "--compact"]) {
                ranges = parseCompactLines(data, as: TickerRange.self)
            }
            group.leave()
        }

        group.wait()

        let rangeMap = Dictionary(uniqueKeysWithValues: ranges.map { ($0.symbol, $0) })
        let dailyMap = Dictionary(uniqueKeysWithValues: daily.map { ($0.symbol, $0) })

        return symbols.compactMap { sym -> TickerQuote? in
            guard let quote = dailyMap[sym], let entry = entryMap[sym] else { return nil }
            let range = rangeMap[sym]
            return TickerQuote.make(
                from: quote,
                entry: entry,
                weekly: range?.weeklyChangePercent,
                ytd: range?.ytdChangePercent,
                sparkline: range?.sparklineCloses
            )
        }
    }

    // MARK: - Yahoo Finance crumb auth

    private static func fetchCrumb() async -> String? {
        // Warm up session to set the necessary cookies
        guard let warmupURL = URL(string: "https://finance.yahoo.com/") else { return nil }
        _ = try? await URLSession.shared.data(from: warmupURL)
        guard let url = URL(string: "https://query2.finance.yahoo.com/v1/test/getcrumb") else { return nil }
        var req = URLRequest(url: url)
        req.setValue(browserAgent, forHTTPHeaderField: "User-Agent")
        guard
            let (data, _) = try? await URLSession.shared.data(for: req),
            let crumb = String(data: data, encoding: .utf8),
            !crumb.isEmpty,
            !crumb.hasPrefix("{")
        else { return nil }
        return crumb
    }

    private static func ensureCrumb() async -> String? {
        if let crumb = cachedCrumb { return crumb }
        let crumb = await fetchCrumb()
        cachedCrumb = crumb
        return crumb
    }

    // MARK: - ETF holdings

    static func fetchTopHoldings(symbol: String) async -> [ETFHolding] {
        if let cached = ETFCache.load(symbol: symbol) { return cached }
        guard let crumb = await ensureCrumb() else { return [] }
        let encodedCrumb = crumb.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? crumb
        guard let url = URL(
            string: "https://query2.finance.yahoo.com/v1/finance/quoteSummary/\(symbol)"
                + "?modules=topHoldings&crumb=\(encodedCrumb)"
        ) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(browserAgent, forHTTPHeaderField: "User-Agent")

        guard
            let (data, _) = try? await URLSession.shared.data(for: request),
            let resp = try? JSONDecoder().decode(YFQuoteSummaryResponse.self, from: data),
            let rawHoldings = resp.quoteSummary.result?.first?.topHoldings?.holdings
        else { return [] }

        let holdings: [ETFHolding] = rawHoldings.compactMap { item in
            guard let sym = item.symbol, let pct = item.holdingPercent else { return nil }
            return ETFHolding(id: sym, symbol: sym, name: item.holdingName ?? sym, percent: pct)
        }
        ETFCache.save(symbol: symbol, holdings: holdings)
        return holdings
    }

    // MARK: - Yahoo Finance search

    static func search(query: String) async -> [TickerSearchResult] {
        guard
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(
                string: "https://query1.finance.yahoo.com/v1/finance/search"
                    + "?q=\(encoded)&quotesCount=8&newsCount=0&enableFuzzyQuery=false"
            )
        else { return [] }

        var request = URLRequest(url: url)
        request.setValue(browserAgent, forHTTPHeaderField: "User-Agent")

        guard
            let (data, _) = try? await URLSession.shared.data(for: request),
            let response = try? JSONDecoder().decode(YFSearchResponse.self, from: data)
        else { return [] }

        return response.quotes.compactMap { $0.toResult() }
    }
}
