import SwiftUI

struct WidgetView: View {
    @ObservedObject var store: WidgetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            tabBar
            searchBar
            if !store.searchResults.isEmpty || store.isSearching {
                searchDropdown
            } else {
                Divider()
                tickerList
            }
            ResizeHandle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await store.refresh() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 6) {
            Text("Stocks")
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
            if store.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else if let date = store.lastRefresh {
                Text(date, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            headerMenu
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var headerMenu: some View {
        Menu {
            Button("Refresh") { Task { await store.forceRefresh() } }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        Picker("", selection: $store.activeTab) {
            ForEach(WidgetTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 6)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Group {
                    if store.isSearching || store.isAdding {
                        ProgressView().scaleEffect(0.55)
                    } else {
                        Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 14)
                .font(.subheadline)

                TextField("Search: bitcoin, nvidia, CAC, solana…", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit {
                        if let first = store.searchResults.first {
                            addResult(first)
                        }
                    }

                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                        store.addError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let error = store.addError {
                Text(error).font(.caption).foregroundStyle(.red).transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.04))
        .animation(.easeInOut(duration: 0.15), value: store.addError)
    }

    // MARK: - Search dropdown

    private var searchDropdown: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.searchResults) { result in
                    SearchResultRow(
                        result: result,
                        alreadyAdded: store.entries.contains { $0.symbol == result.symbol }
                    ) {
                        addResult(result)
                    }
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    // MARK: - Ticker list

    @ViewBuilder
    private var tickerList: some View {
        let visible = store.visibleTickers
        if visible.isEmpty && store.isLoading {
            Spacer()
            ProgressView().scaleEffect(0.7).frame(maxWidth: .infinity)
            Spacer()
        } else if visible.isEmpty {
            Spacer()
            emptyState
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visible) { ticker in
                        TickerRow(ticker: ticker) { store.removeTicker(ticker.symbol) }
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No \(store.activeTab.rawValue.lowercased()) yet.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Search above to add one.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func addResult(_ result: TickerSearchResult) {
        let symbol = result.symbol
        let quoteType = result.quoteType
        store.searchQuery = ""
        Task { await store.addTicker(symbol: symbol, quoteType: quoteType) }
    }
}
