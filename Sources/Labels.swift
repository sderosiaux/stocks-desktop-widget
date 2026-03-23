import Foundation

enum Labels {
    // MARK: - Type properties (must come before methods per type_contents_order)

    static let majorExchanges: Set<String> = [
        // US
        "NMS", "NGM", "NCM", "NYQ", "NYB", "PCX", "BATS",
        // EU main
        "PAR", "GER", "LSE", "AMS", "BRU", "MIL", "STO", "HEL", "OSL", "LIS", "ATH", "VIE", "EBS",
        // Indices
        "SNP", "DJI", "WCB", "FGI",
        // Other major
        "TOR", "ASX", "TSE", "HKG"
    ]

    private static let exchangeNames: [String: String] = [
        // US
        "NMS": "NASDAQ", "NGM": "NASDAQ", "NCM": "NASDAQ",
        "NYQ": "NYSE", "NYB": "NYSE",
        "PCX": "NYSE Arca",
        "BATS": "BATS",
        "OTC": "OTC",
        // EU
        "PAR": "Paris",
        "GER": "Xetra",
        "LSE": "London",
        "AMS": "Amsterdam",
        "BRU": "Brussels",
        "MIL": "Milan",
        "STO": "Stockholm",
        "HEL": "Helsinki",
        "OSL": "Oslo",
        "LIS": "Lisbon",
        "ATH": "Athens",
        "VIE": "Vienna",
        "EBS": "Vienna",
        // Indices
        "SNP": "S&P",
        "DJI": "Dow Jones",
        "WCB": "World",
        "FGI": "FTSE",
        // Crypto / Forex
        "CCC": "Crypto",
        "CCY": "Forex",
        // Other major
        "TOR": "Toronto",
        "ASX": "Sydney",
        "TSE": "Tokyo",
        "HKG": "Hong Kong"
    ]

    // MARK: - Market state

    static func marketStateDescription(_ state: String) -> String {
        switch state {
        case "REGULAR": return "Market open"

        case "PRE": return "Pre-market"

        case "POST": return "After hours"

        case "PREPRE": return "Pre-market (early)"

        case "CLOSED": return "Market closed"

        case "POSTPOST": return "After hours (late)"

        default: return state
        }
    }

    // MARK: - Quote type

    static func quoteTypeLabel(_ type: String) -> String {
        switch type {
        case "EQUITY": return "Stock"

        case "ETF": return "ETF"

        case "CRYPTOCURRENCY": return "Crypto"

        case "CURRENCY": return "Forex"

        case "INDEX": return "Index"

        case "MUTUALFUND": return "Fund"

        case "FUTURE": return "Future"

        default: return type
        }
    }

    static func quoteTypeDescription(_ type: String) -> String {
        switch type {
        case "EQUITY": return "Company stock listed on a stock exchange"

        case "ETF": return "Exchange Traded Fund — basket of assets"

        case "CRYPTOCURRENCY": return "Digital currency (crypto)"

        case "CURRENCY": return "Forex currency pair"

        case "INDEX": return "Market index tracking a group of stocks"

        case "MUTUALFUND": return "Actively managed investment fund"

        case "FUTURE": return "Futures contract"

        default: return type
        }
    }

    // MARK: - Exchange

    static func exchangeName(_ code: String) -> String {
        exchangeNames[code] ?? code
    }
}
