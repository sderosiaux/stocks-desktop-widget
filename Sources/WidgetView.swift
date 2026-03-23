import SwiftUI

struct WidgetView: View {
    @ObservedObject var store: WidgetStore
    let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            contentSection
            ResizeHandle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await store.refresh() }
        .onReceive(timer) { _ in
            Task { await store.refresh() }
        }
    }

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
            Button("Refresh") {
                Task { await store.forceRefresh() }
            }
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    @ViewBuilder
    private var contentSection: some View {
        if store.tickers.isEmpty && store.isLoading {
            Spacer()
            ProgressView()
                .scaleEffect(0.7)
                .frame(maxWidth: .infinity)
            Spacer()
        } else if store.tickers.isEmpty {
            Spacer()
            Text("No data.\nCheck ticker-cli is installed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.tickers) { ticker in
                        TickerRow(ticker: ticker)
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
    }
}
