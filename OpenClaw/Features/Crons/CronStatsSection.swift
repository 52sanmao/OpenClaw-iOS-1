import SwiftUI

/// Run statistics section for the cron detail view.
struct CronStatsSection: View {
    let stats: CronDetailViewModel.RunStats

    var body: some View {
        Section("Run Stats") {
            // Primary model
            if let model = stats.primaryModel {
                LabeledContent("Model") {
                    ModelPill(model: model)
                }
            }

            // Average duration
            LabeledContent("Avg Duration") {
                Text(stats.avgDurationFormatted)
                    .font(AppTypography.captionMono)
            }

            // Average tokens
            LabeledContent("Avg Tokens") {
                Text(Formatters.tokens(stats.avgTokens))
                    .font(AppTypography.captionMono)
                    .foregroundStyle(AppColors.metricPrimary)
            }

            // Total tokens
            LabeledContent("Total Tokens") {
                Text(Formatters.tokens(stats.totalTokens))
                    .font(AppTypography.captionMono)
                    .foregroundStyle(AppColors.metricPrimary)
            }

            // Success rate
            LabeledContent("Success Rate") {
                HStack(spacing: Spacing.xs) {
                    Text(String(format: "%.0f%%", stats.successRate * 100))
                        .font(AppTypography.captionBold)
                        .foregroundStyle(rateColor)
                    Text("(\(stats.runCount) runs)")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }

            // Success rate bar
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
            .accessibilityLabel("Success rate \(String(format: "%.0f", stats.successRate * 100)) percent")
        }
    }

    private var rateColor: Color {
        AppColors.gauge(percent: stats.successRate * 100, warn: 80, critical: 50)
    }
}
