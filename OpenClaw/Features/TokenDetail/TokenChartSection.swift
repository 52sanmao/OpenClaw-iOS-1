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
                    label: "缓存命中",
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
            SectorMark(angle: .value("输入", usage.totals.inputTokens))
                .foregroundStyle(AppColors.metricPrimary)
            SectorMark(angle: .value("输出", usage.totals.outputTokens))
                .foregroundStyle(AppColors.metricPositive)
            SectorMark(angle: .value("缓存读取", usage.totals.cacheReadTokens))
                .foregroundStyle(AppColors.metricHighlight)
            SectorMark(angle: .value("缓存写入", usage.totals.cacheWriteTokens))
                .foregroundStyle(AppColors.metricTertiary)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 2) {
                Text(Formatters.tokens(usage.totals.totalTokens))
                    .font(AppTypography.captionBold)
                Text("令牌")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
        }
        .frame(width: 120, height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("令牌分布：输入 \(Formatters.tokens(usage.totals.inputTokens))，输出 \(Formatters.tokens(usage.totals.outputTokens))，缓存读取 \(Formatters.tokens(usage.totals.cacheReadTokens))，缓存写入 \(Formatters.tokens(usage.totals.cacheWriteTokens))")
    }

    // MARK: - Cost Bar

    private var costByModelChart: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("按模型统计成本")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.neutral)

            Chart(paidModels) { model in
                BarMark(
                    x: .value("Cost", model.costUsd),
                    y: .value("Model", Formatters.modelShortName(model.fullModel))
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
            .accessibilityLabel("按模型统计成本图表，共 \(paidModels.count) 个模型")
        }
    }
}
