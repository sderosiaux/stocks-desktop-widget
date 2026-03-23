import Foundation

struct TickerSearchResult: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let quoteType: String
    let exchange: String

    var typeLabel: String { Labels.quoteTypeLabel(quoteType) }
    var exchangeName: String { Labels.exchangeName(exchange) }
}

// MARK: - Yahoo Finance API response

struct YFSearchResponse: Decodable {
    struct YFQuote: Decodable {
        let symbol: String
        let shortname: String?
        let longname: String?
        let quoteType: String?
        let exchange: String?
    }

    let quotes: [YFQuote]
}

extension YFSearchResponse.YFQuote {
    func toResult() -> TickerSearchResult? {
        guard let quoteType, quoteType != "OPTION", quoteType != "FUTURE" else { return nil }
        // For equities and funds, restrict to major exchanges only
        let isTraded = ["EQUITY", "ETF", "MUTUALFUND"].contains(quoteType)
        if isTraded {
            guard let exchange, Labels.majorExchanges.contains(exchange) else { return nil }
        }
        return TickerSearchResult(
            id: symbol,
            symbol: symbol,
            name: shortname ?? longname ?? symbol,
            quoteType: quoteType,
            exchange: exchange ?? ""
        )
    }
}
