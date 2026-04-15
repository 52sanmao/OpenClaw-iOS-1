import SwiftUI

/// 2-column metric grid for the token detail page.
struct TokenSummaryGrid: View {
    let totals: TokenUsage.Totals

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            MetricCell(label: "总令牌数", value: Formatters.tokens(totals.totalTokens), color: AppColors.metricPrimary)
            MetricCell(label: "成本", value: Formatters.cost(totals.costUsd), color: AppColors.metricWarm)
            MetricCell(label: "输入", value: Formatters.tokens(totals.inputTokens), color: AppColors.metricPrimary)
            MetricCell(label: "输出", value: Formatters.tokens(totals.outputTokens), color: AppColors.metricPositive)
            MetricCell(label: "缓存读取", value: Formatters.tokens(totals.cacheReadTokens), color: AppColors.metricHighlight)
            MetricCell(label: "缓存写入", value: Formatters.tokens(totals.cacheWriteTokens), color: AppColors.metricTertiary)
            MetricCell(label: "请求", value: "\(totals.requestCount)", color: AppColors.neutral)
            MetricCell(label: "工具调用", value: "\(totals.toolRequests)", color: AppColors.metricWarm)
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
