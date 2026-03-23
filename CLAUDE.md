# CLAUDE.md — stocks-desktop-widget

## Project overview

Native macOS desktop widget (SwiftUI + AppKit) for stock monitoring. No sandboxing, no App Store. Borderless floating HUD window at desktop level. Menu bar status item shows portfolio direction. Powered by [`ticker-cli`](https://github.com/sderosiaux/ticker-cli).

## Architecture

```
Sources/
├── main.swift              — NSApplication entry point
├── AppDelegate.swift       — window setup + NSStatusItem menu bar
├── Models.swift            — SymbolEntry, TickerDaily, TickerRange, TickerQuote, WidgetTab
├── DisplayNames.swift      — extension TickerQuote { displayNames } — 200+ entries
├── TickerService.swift     — ticker-cli subprocess calls + Yahoo Finance HTTP
├── WidgetStore.swift       — ObservableObject: tickers, entries, refresh loop, search
├── WidgetView.swift        — root view: header + tabs + search bar + list/dropdown
├── TickerRow.swift         — one ticker row: dot/×, symbol, sparkline, price, trends, ETF pie
├── SearchResultRow.swift   — one search result row: symbol, badge, exchange, add button
├── ETFHoldingsView.swift   — popover showing top 10 ETF holdings
├── QuoteCache.swift        — disk cache for quote prices + sparklines (XDG, 5-min TTL)
├── ETFCache.swift          — disk cache for ETF holdings (XDG, 24h TTL)
├── SymbolStore.swift       — persists symbol+quoteType list (XDG data home)
├── MarketCalendar.swift    — refreshInterval(): 60s/180s/300s by market session
├── Labels.swift            — market state, quote type, exchange labels
├── SearchResult.swift      — TickerSearchResult + YFSearchResponse decodable
├── ETFHolding.swift        — ETFHolding + YF quoteSummary decodable structs
├── ResizableWindow.swift   — NSWindow subclass with drag-to-resize corner
└── ResizeHandle.swift      — SwiftUI resize indicator (bottom-right)
```

## Key patterns

### Data flow
1. App starts → `WidgetStore.init()` loads `SymbolStore` + `QuoteCache` (instant display)
2. `.task` triggers `store.refresh()` → skips if cache fresh, else calls `TickerService.fetchQuotes`
3. `AppDelegate` calls `store.startRefreshLoop()` → adaptive timer loop via `MarketCalendar`
4. Manual refresh (⋯ menu) → `store.forceRefresh()` → always fetches

### ticker-cli integration
- Binary at `~/go/bin/ticker-cli` — see https://github.com/sderosiaux/ticker-cli
- Called via `/bin/zsh -c "ticker-cli ... > tmpfile"` (stdout to temp file, stderr discarded)
- **2 parallel calls** via `DispatchGroup`:
  1. `ticker-cli [symbols] --format json --compact` → daily price, change, marketState, currency
  2. `ticker-cli [symbols] --range ytd --format json --compact` → OHLCV history (derives weekly, YTD, sparklines)
- Output: one JSON object per line (compact mode)

### Sparklines
- Derived from `--range ytd` output: last 30 closes after deduplication by date
- Weekly change: `points[-1]` vs `points[-6]` (5 trading days)
- YTD change: `points[-1]` vs `points[0]`
- Rendered as SwiftUI `Path` (50×14px) in each `TickerRow`, green/red based on 30-day direction
- Cached alongside quote prices in `QuoteCache` (serialized as `[Double]?`)

### Yahoo Finance (direct HTTP, no key needed)
- **Crumb auth required** (as of 2025): warm up via `GET finance.yahoo.com/`, then `GET query2.../v1/test/getcrumb`. Pass crumb as `?crumb=` param. Cached in memory per session.
- Search: `query1.finance.yahoo.com/v1/finance/search?q=...`
- ETF holdings: `query2.finance.yahoo.com/v1/finance/quoteSummary/{SYMBOL}?modules=topHoldings&crumb=...`
- User-Agent: full Chrome string required (see `TickerService.browserAgent`)
- Search results filtered to `Labels.majorExchanges` for EQUITY/ETF types
- `OPTION` and `FUTURE` types excluded from search results and Markets tab

### Menu bar status item
- `NSStatusItem` in AppDelegate, shows `▲ 1.2%` / `▼ 0.8%` (average daily change, all tickers)
- Colored via `NSAttributedString` — subscribes to `store.$tickers` via `AnyCancellable`
- Click toggles main window visibility

### Cache hierarchy
| Layer | File | TTL | Content |
|-------|------|-----|---------|
| QuoteCache | `~/.cache/stocks-widget/quotes.json` | 5 min | All TickerQuote (price, changes, sparkline closes) |
| ETFCache | `~/.cache/stocks-widget/etf-holdings.json` | 24 h | Holdings per ETF symbol |
| SymbolStore | `~/.local/share/stocks-widget/symbols.json` | permanent | [SymbolEntry] |

Both `XDG_CACHE_HOME` and `XDG_DATA_HOME` respected; fall back to `~/.cache` / `~/.local/share`.

### Tab categorization
- **Stocks** → `EQUITY`
- **ETF** → `ETF`, `MUTUALFUND`
- **Markets** → everything else — `FUTURE` excluded entirely

### Adaptive refresh
`MarketCalendar.refreshInterval()` uses Unix timestamp (always UTC):
- EU/US active trading (07:00–20:00 UTC on weekdays): **60s**
- US pre/post-market (11:00–13:30 and 20:00+ UTC): **180s**
- Overnight + weekends: **300s**

### SwiftLint rules
Config in `.swiftlint.yml` with `strict: true`. Key constraints:
- `force_cast: error`, `force_try: error`, `force_unwrapping: error`
- `type_contents_order`: static props → instance props → init → computed props → methods
- No trailing commas in collection literals
- `identifier_name` min 2 chars
- Function body ≤ 40 lines, file ≤ 300 lines, type body ≤ 200 lines, nesting ≤ 2 levels
- `DisplayNames.swift` uses extension to keep `Models.swift` under limits

Pre-commit hook at `.git/hooks/pre-commit` blocks commits on violations.

## Build & deploy

```bash
# Dev
swift run

# Check
swift build && swiftlint lint

# Deploy (after changes)
swift build -c release
cp .build/release/StocksWidget ~/.local/bin/StocksWidget
pkill StocksWidget && ~/.local/bin/StocksWidget &
```

Launch agent: `~/Library/LaunchAgents/com.stocks-widget.plist` → auto-starts at login.

## Adding new tickers to defaults

Edit `SymbolEntry.defaults` in `Models.swift`. The `quoteType` must match Yahoo Finance (`EQUITY`, `ETF`, `INDEX`, `CURRENCY`, `CRYPTOCURRENCY`). Never use `FUTURE`.

Add friendly name in `DisplayNames.swift` if needed (especially for indices `^...` and forex `...=X`).

To apply to an existing install without resetting the user list, edit `~/.local/share/stocks-widget/symbols.json` directly.

## Common pitfalls

- **ticker-cli PATH**: binary at `~/go/bin/` — `TickerService.runCLI` adds it to PATH explicitly
- **type_contents_order**: `var body` is a computed property → must come before methods; `@ViewBuilder var` is also computed
- **Nesting limit**: keep Codable response structs at top-level (see `ETFHolding.swift`, `ETFCache.swift`)
- **DisplayNames in extension**: SourceKit may show false "no member" warnings — it compiles fine
- **Yahoo Finance crumb**: `TickerService.cachedCrumb` is an in-memory cache. On 401, set to `nil` to force re-auth on next refresh.
- **Sparkline deduplication**: ticker-cli `--range` returns the last trading day twice. `TickerRange.deduped` filters by date.
- **Self vs type name**: inside a type, use `Self(...)` and `Self.property` to satisfy `prefer_self_in_static_references`
