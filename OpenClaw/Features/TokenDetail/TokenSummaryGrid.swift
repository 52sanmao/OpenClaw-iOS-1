import SwiftUI

/// 2-column metric grid for the token detail page.
struct TokenSummaryGrid: View {
    let totals: TokenUsage.Totals

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            MetricCell(label: "Total Tokens", value: Formatters.tokens(totals.totalTokens), color: AppColors.metricPrimary)
            MetricCell(label: "Cost", value: Formatters.cost(totals.costUsd), color: AppColors.metricWarm)
            MetricCell(label: "Input", value: Formatters.tokens(totals.inputTokens), color: AppColors.metricPrimary)
            MetricCell(label: "Output", value: Formatters.tokens(totals.outputTokens), color: AppColors.metricPositive)
            MetricCell(label: "Cache Read", value: Formatters.tokens(totals.cacheReadTokens), color: AppColors.metricHighlight)
            MetricCell(label: "Cache Write", value: Formatters.tokens(totals.cacheWriteTokens), color: AppColors.metricTertiary)
            MetricCell(label: "Requests", value: "\(totals.requestCount)", color: AppColors.neutral)
            MetricCell(label: "Tool Use", value: "\(totals.toolRequests)", color: AppColors.metricWarm)
        }
    }
}

private struct MetricCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(value)
                .font(AppTypography.metricValue)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(AppColors.tintedBackground(color, opacity: 0.06), in: RoundedRectangle(cornerRadius: AppRadius.sm))
        .accessibilityElement(children: .combine)
    }
}
