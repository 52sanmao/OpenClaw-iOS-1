import Charts
import SwiftUI

/// Donut chart + cache gauge + cost-by-model bar.
struct TokenChartSection: View {
    let usage: TokenUsage

    private var paidModels: [TokenUsage.ModelUsage] {
        usage.byModel.filter { $0.costUsd > 0 }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Row: donut + cache gauge
            HStack(alignment: .top, spacing: Spacing.md) {
                tokenDonut
                Spacer()
                RingGauge(
                    value: usage.totals.cacheHitRate,
                    label: "Cache Hit",
                    color: AppColors.metricHighlight
                )
            }

            // Cost by model bar chart
            if !paidModels.isEmpty {
                costByModelChart
            }
        }
    }

    // MARK: - Donut

    private var tokenDonut: some View {
        Chart {
            SectorMark(angle: .value("Input", usage.totals.inputTokens))
                .foregroundStyle(AppColors.metricPrimary)
            SectorMark(angle: .value("Output", usage.totals.outputTokens))
                .foregroundStyle(AppColors.metricPositive)
            SectorMark(angle: .value("Cache Read", usage.totals.cacheReadTokens))
                .foregroundStyle(AppColors.metricHighlight)
            SectorMark(angle: .value("Cache Write", usage.totals.cacheWriteTokens))
                .foregroundStyle(AppColors.metricTertiary)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text(Formatters.tokens(usage.totals.totalTokens))
                    .font(AppTypography.captionBold)
                Text("tokens")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Token distribution: \(Formatters.tokens(usage.totals.inputTokens)) input, \(Formatters.tokens(usage.totals.outputTokens)) output, \(Formatters.tokens(usage.totals.cacheReadTokens)) cache read, \(Formatters.tokens(usage.totals.cacheWriteTokens)) cache write")
    }

    // MARK: - Cost Bar

    private var costByModelChart: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Cost by Model")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.neutral)

            Chart(paidModels) { model in
                BarMark(
                    x: .value("Cost", model.costUsd),
                    y: .value("Model", Formatters.modelShortName(model.model))
                )
                .foregroundStyle(AppColors.metricWarm)
                .annotation(position: .trailing) {
                    Text(Formatters.cost(model.costUsd))
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                }
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .frame(height: CGFloat(paidModels.count) * 32 + Spacing.md)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cost by model chart, \(paidModels.count) models")
        }
    }
}
