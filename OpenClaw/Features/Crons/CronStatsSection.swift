import SwiftUI

/// Run statistics section for the cron detail view.
struct CronStatsSection: View {
    let stats: CronDetailViewModel.RunStats

    var body: some View {
        Section("运行统计") {
            LabeledContent("平均耗时") {
                Text(stats.avgDurationFormatted)
                    .font(AppTypography.captionMono)
            }

            LabeledContent("平均令牌数") {
                Text(Formatters.tokens(stats.avgTokens))
                    .font(AppTypography.captionMono)
                    .foregroundStyle(AppColors.metricPrimary)
            }

            LabeledContent("总令牌数") {
                Text(Formatters.tokens(stats.totalTokens))
                    .font(AppTypography.captionMono)
                    .foregroundStyle(AppColors.metricPrimary)
            }

            LabeledContent("成功率") {
                HStack(spacing: Spacing.xs) {
                    Text(String(format: "%.0f%%", stats.successRate * 100))
                        .font(AppTypography.captionBold)
                        .foregroundStyle(rateColor)
                    Text("(\(stats.runCount) 次运行)")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.neutral.opacity(0.15))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(rateColor)
                            .frame(width: max(geo.size.width * stats.successRate, stats.successRate > 0 ? 2 : 0))
                    }
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("成功率 \(String(format: "%.0f", stats.successRate * 100)) 百分比")
        }
    }

    private var rateColor: Color {
        AppColors.gauge(percent: stats.successRate * 100, warn: 80, critical: 50)
    }
}
