import Foundation

// Returns the appropriate polling interval based on market session.
// All times in UTC. DST is approximated (±1h edge cases are acceptable).
//
//  EU regular  08:00–17:30 CET  = 07:00–16:30 UTC
//  US regular  09:30–16:00 ET   = 13:30–20:00 UTC (EDT)
//  US pre      07:00–09:30 ET   = 11:00–13:30 UTC
//  US post     16:00–20:00 ET   = 20:00–00:00 UTC

enum MarketCalendar {
    static func refreshInterval() -> TimeInterval {
        let now = Date()
        let weekday = Calendar.current.component(.weekday, from: now)
        guard weekday != 1, weekday != 7 else { return 300 } // Sat/Sun

        // Unix timestamp is always UTC — no timezone conversion needed
        let utcMins = (Int(now.timeIntervalSince1970) % 86_400) / 60

        let euOpen    = 7 * 60       // 07:00 UTC (08:00 CET)
        let euClose   = 16 * 60 + 30 // 16:30 UTC (17:30 CET)
        let usOpen    = 13 * 60 + 30 // 13:30 UTC (09:30 EDT)
        let usClose   = 20 * 60      // 20:00 UTC (16:00 EDT)
        let usPreOpen = 11 * 60      // 11:00 UTC (07:00 EDT)

        let activeTrading = (utcMins >= euOpen && utcMins < euClose)
            || (utcMins >= usOpen && utcMins < usClose)
        if activeTrading { return 60 }

        let extendedHours = (utcMins >= usPreOpen && utcMins < usOpen) || utcMins >= usClose
        if extendedHours { return 180 }

        return 300 // overnight 00:00–07:00 UTC
    }
}
