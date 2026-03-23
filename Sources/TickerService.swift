import Foundation

enum TickerService {
    private static let tickerCLI = "/Users/sderosiaux/go/bin/ticker-cli"

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

    static func fetchQuotes(symbols: [String]) -> [TickerQuote] {
        let symbolArgs = symbols

        // Run all 3 calls in parallel via DispatchGroup
        var daily: [TickerDaily] = []
        var weekly: [TickerPeriod] = []
        var ytd: [TickerPeriod] = []

        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            if let data = runCLI(symbolArgs + ["--format", "json", "--compact"]) {
                daily = parseCompactLines(data, as: TickerDaily.self)
            }
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            if let data = runCLI(symbolArgs + ["--weekly-change", "--format", "json", "--compact"]) {
                weekly = parseCompactLines(data, as: TickerPeriod.self)
            }
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            if let data = runCLI(symbolArgs + ["--ytd", "--format", "json", "--compact"]) {
                ytd = parseCompactLines(data, as: TickerPeriod.self)
            }
            group.leave()
        }

        group.wait()

        let weeklyMap = Dictionary(uniqueKeysWithValues: weekly.map { ($0.symbol, $0.changePercent) })
        let ytdMap = Dictionary(uniqueKeysWithValues: ytd.map { ($0.symbol, $0.changePercent) })

        // Preserve input order
        let dailyMap = Dictionary(uniqueKeysWithValues: daily.map { ($0.symbol, $0) })
        return symbols.compactMap { sym -> TickerQuote? in
            guard let quote = dailyMap[sym] else { return nil }
            return TickerQuote.make(from: quote, weekly: weeklyMap[sym], ytd: ytdMap[sym])
        }
    }
}
