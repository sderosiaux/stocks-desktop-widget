import Foundation

// MARK: - Codable types (top-level to avoid nesting violations)

struct ETFCacheStore: Codable {
    var entries: [String: ETFCacheEntry]
}

struct ETFCacheEntry: Codable {
    let holdings: [ETFCachedHolding]
    let fetchedAt: Date
}

struct ETFCachedHolding: Codable {
    let symbol: String
    let name: String
    let percent: Double
}

// MARK: - Cache API

enum ETFCache {
    static let ttl: TimeInterval = 24 * 60 * 60

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
        cacheDir.appendingPathComponent("etf-holdings.json")
    }

    static func load(symbol: String) -> [ETFHolding]? {
        guard
            let data = try? Data(contentsOf: cacheFile),
            let store = try? JSONDecoder().decode(ETFCacheStore.self, from: data),
            let entry = store.entries[symbol],
            Date().timeIntervalSince(entry.fetchedAt) < ttl
        else { return nil }

        return entry.holdings.map {
            ETFHolding(id: $0.symbol, symbol: $0.symbol, name: $0.name, percent: $0.percent)
        }
    }

    static func save(symbol: String, holdings: [ETFHolding]) {
        var store = (try? JSONDecoder().decode(
            ETFCacheStore.self,
            from: (try? Data(contentsOf: cacheFile)) ?? Data()
        )) ?? ETFCacheStore(entries: [:])

        store.entries[symbol] = ETFCacheEntry(
            holdings: holdings.map { ETFCachedHolding(symbol: $0.symbol, name: $0.name, percent: $0.percent) },
            fetchedAt: Date()
        )
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: cacheFile)
    }
}
