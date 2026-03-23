import Foundation

enum SymbolStore {
    private static var dataDir: URL {
        let base: URL
        if let xdg = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] {
            base = URL(fileURLWithPath: xdg)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/share")
        }
        let dir = base.appendingPathComponent("stocks-widget")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var dataFile: URL {
        dataDir.appendingPathComponent("symbols.json")
    }

    static func load() -> [SymbolEntry]? {
        guard let data = try? Data(contentsOf: dataFile) else { return nil }

        // New format: [{symbol, quoteType}]
        if let entries = try? JSONDecoder().decode([SymbolEntry].self, from: data), !entries.isEmpty {
            return entries
        }

        // Legacy format: [String] — infer quoteType from symbol pattern
        if let symbols = try? JSONDecoder().decode([String].self, from: data), !symbols.isEmpty {
            return symbols.map { SymbolEntry(symbol: $0, quoteType: SymbolEntry.infer(symbol: $0)) }
        }

        return nil
    }

    static func save(_ entries: [SymbolEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: dataFile)
    }
}
