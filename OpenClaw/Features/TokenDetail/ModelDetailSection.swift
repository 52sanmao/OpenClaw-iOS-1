import SwiftUI

/// Expanded per-model rows with full token breakdown.
struct ModelDetailSection: View {
    let models: [TokenUsage.ModelUsage]

    var body: some View {
        ForEach(models) { model in
            ModelDetailRow(model: model)
        }
    }
}

private struct ModelDetailRow: View {
    let model: TokenUsage.ModelUsage

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Header: name + cost
            HStack(spacing: Spacing.xs) {
                ModelPill(model: model.fullModel)
                Spacer()

                Text(model.costUsd > 0 ? Formatters.cost(model.costUsd) : "已包含")
                    .font(AppTypography.captionBold)
                    .foregroundStyle(model.costUsd > 0 ? AppColors.metricWarm : AppColors.neutral)
            }

            // Token totals
            HStack(spacing: Spacing.sm) {
                Text(Formatters.tokens(model.totalTokens))
                    .font(AppTypography.metricValue)
                    .foregroundStyle(AppColors.metricPrimary)

                Text("\(model.requestCount) 次请求")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)

                Spacer()
            }

            // Token breakdown bar (input/output/cache)
            ModelTokenBar(model: model)

            // Stats row
            HStack(spacing: Spacing.sm) {
                if model.thinkingRequests > 0 {
                    Label("\(model.thinkingRequests) 次思考", systemImage: "brain.head.profile")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.metricTertiary)
                }
                if model.toolRequests > 0 {
                    Label("\(model.toolRequests) 次工具调用", systemImage: "terminal")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.metricWarm)
                }
                if model.cacheHitRate > 0 {
                    Label(String(format: "%.0f%% 缓存命中", model.cacheHitRate * 100), systemImage: "bolt.fill")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.metricHighlight)
                }
                Spacer()
            }
        }
        .padding(Spacing.sm)
        .background(AppColors.tintedBackground(AppColors.neutral, opacity: 0.04), in: RoundedRectangle(cornerRadius: AppRadius.md))
        .accessibilityElement(children: .combine)
    }
}

/// 4-segment bar for per-model token breakdown.
private struct ModelTokenBar: View {
    let model: TokenUsage.ModelUsage

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            GeometryReader { geo in
                let w = geo.size.width
                let total = max(model.totalTokens, 1)
                HStack(spacing: 1) {
                    segment(model.inputTokens, total, w, AppColors.metricPrimary)
                    segment(model.outputTokens, total, w, AppColors.metricPositive)
                    segment(model.cacheReadTokens, total, w, AppColors.metricHighlight)
                    segment(model.cacheWriteTokens, total, w, AppColors.metricTertiary)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            HStack(spacing: Spacing.sm) {
                TokenLegendItem(color: AppColors.metricPrimary, label: "输入", value: model.inputTokens)
                TokenLegendItem(color: AppColors.metricPositive, label: "输出", value: model.outputTokens)
                TokenLegendItem(color: AppColors.metricHighlight, label: "缓存读", value: model.cacheReadTokens)
                TokenLegendItem(color: AppColors.metricTertiary, label: "缓存写", value: model.cacheWriteTokens)
                Spacer()
            }
        }
    }

    private func segment(_ value: Int, _ total: Int, _ width: CGFloat, _ color: Color) -> some View {
        let p = CGFloat(value) / CGFloat(total)
        return Rectangle().fill(color).frame(width: max(p * width, value > 0 ? 2 : 0))
    }
}
