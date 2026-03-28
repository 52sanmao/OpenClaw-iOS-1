import SwiftUI

/// Shows token usage per pipeline with proportional bars.
struct PipelineBreakdownSection: View {
    let breakdown: PipelineBreakdown?
    let totalTokens: Int
    let isLoading: Bool
    let error: Error?

    var body: some View {
        if isLoading && breakdown == nil {
            CardLoadingView(minHeight: 80)
        } else if let error, breakdown == nil {
            CardErrorView(error: error, minHeight: 60)
        } else if let breakdown {
            VStack(spacing: Spacing.xs) {
                // Main session (non-cron usage)
                if breakdown.mainSession.totalTokens > 0 {
                    PipelineRow(
                        name: breakdown.mainSession.name,
                        tokens: breakdown.mainSession.totalTokens,
                        totalTokens: totalTokens,
                        runCount: nil
                    )
                }

                ForEach(breakdown.pipelines) { pipeline in
                    PipelineRow(
                        name: pipeline.name,
                        tokens: pipeline.totalTokens,
                        totalTokens: totalTokens,
                        runCount: pipeline.runCount
                    )
                }
            }
        }
    }
}

private struct PipelineRow: View {
    let name: String
    let tokens: Int
    let totalTokens: Int
    let runCount: Int?

    private var percent: Double {
        guard totalTokens > 0 else { return 0 }
        return Double(tokens) / Double(totalTokens)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(name)
                    .font(AppTypography.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(Formatters.tokens(tokens))
                    .font(AppTypography.captionMono)
                    .foregroundStyle(AppColors.metricPrimary)
                Text(String(format: "(%.0f%%)", percent * 100))
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            // Proportional bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.metricPrimary.opacity(0.15))
                    .frame(width: geo.size.width)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.metricPrimary)
                            .frame(width: max(geo.size.width * percent, percent > 0 ? 2 : 0))
                    }
            }
            .frame(height: 6)

            if let runCount, runCount > 0 {
                Text("\(runCount) runs")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(Formatters.tokens(tokens)), \(String(format: "%.0f percent", percent * 100))\(runCount.map { ", \($0) runs" } ?? "")")
    }
}
