import SwiftUI

struct ETFHoldingsView: View {
    let symbol: String
    let holdings: [ETFHolding]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if isLoading {
                loadingState
            } else if holdings.isEmpty {
                emptyState
            } else {
                holdingsList
            }
        }
        .frame(width: 260)
    }

    private var header: some View {
        HStack {
            Text("Top Holdings")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Text(symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView().scaleEffect(0.7)
            Spacer()
        }
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        Text("No holdings data available.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(12)
    }

    private var holdingsList: some View {
        VStack(spacing: 0) {
            ForEach(holdings.prefix(10)) { holding in
                holdingRow(holding)
                if holding.id != holdings.prefix(10).last?.id {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func holdingRow(_ holding: ETFHolding) -> some View {
        HStack(spacing: 8) {
            Text(holding.symbol)
                .font(.system(size: 11, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: 52, alignment: .leading)
            Text(holding.name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(String(format: "%.1f%%", holding.percent * 100))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}
