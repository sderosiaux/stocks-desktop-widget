import Foundation

struct ETFHolding: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let percent: Double
}

// MARK: - Yahoo Finance quoteSummary response (flattened to avoid deep nesting)

struct YFQuoteSummaryResponse: Decodable {
    let quoteSummary: YFQuoteSummary
}

struct YFQuoteSummary: Decodable {
    let result: [YFQuoteSummaryResult]?
}

struct YFQuoteSummaryResult: Decodable {
    let topHoldings: YFTopHoldings?
}

struct YFTopHoldings: Decodable {
    let holdings: [YFHolding]?
}

struct YFHolding: Decodable {
    let symbol: String?
    let holdingName: String?
    let holdingPercent: Double?
}
