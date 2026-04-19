import Charts
import SwiftUI

struct TokenTimelinePanel: View {
    let usage: TokenUsage
    let period: TokenPeriod
    var compact: Bool = false

    private var timeline: [TokenUsage.TimelineBucket] {
        usage.timeline
    }

    private var peakBucket: TokenUsage.TimelineBucket? {
        timeline.max { $0.totalTokens < $1.totalTokens }
    }

    private var activeBucketCount: Int {
        timeline.filter { $0.totalTokens > 0 }.count
    }

    private var averageTokens: Int {
        guard !timeline.isEmpty else { return 0 }
        return usage.totals.totalTokens / timeline.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Spacing.xs : Spacing.sm) {
            if compact {
                HStack(alignment: .firstTextBaseline) {
                    Text("时间趋势")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.neutral)
                    Spacer()
                    if let peakBucket {
                        Text("峰值 \(Formatters.tokens(peakBucket.totalTokens))")
                            .font(AppTypography.nano)
                            .foregroundStyle(AppColors.metricPrimary)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    timelineMetric(
                        label: "峰值",
                        value: Formatters.tokens(peakBucket?.totalTokens ?? 0),
                        detail: peakBucket.map { bucketDescriptor(for: $0) } ?? "暂无数据",
                        color: AppColors.metricPrimary
                    )
                    timelineMetric(
                        label: "平均",
                        value: Formatters.tokens(averageTokens),
                        detail: "每个时间桶",
                        color: AppColors.metricHighlight
                    )
                    timelineMetric(
                        label: "活跃桶",
                        value: "\(activeBucketCount)",
                        detail: period == .week ? "最近 7 天" : "小时分布",
                        color: AppColors.metricWarm
                    )
                }
            }

            TokenTimelineChart(usage: usage, period: period, compact: compact)

            if !compact, let peakBucket {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "waveform.path.ecg")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.metricPrimary)
                    Text("最高使用出现在 \(bucketDescriptor(for: peakBucket))")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
    }

    private func timelineMetric(label: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
            Text(value)
                .font(AppTypography.metricValue)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(detail)
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(AppColors.tintedBackground(color, opacity: 0.08), in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func bucketDescriptor(for bucket: TokenUsage.TimelineBucket) -> String {
        switch period {
        case .today, .yesterday:
            return "\(bucket.label):00"
        case .week:
            return bucket.label
        }
    }
}

private struct TokenTimelineChart: View {
    let usage: TokenUsage
    let period: TokenPeriod
    let compact: Bool

    private var timeline: [TokenUsage.TimelineBucket] {
        usage.timeline
    }

    private var maxTokens: Int {
        max(timeline.map(\.totalTokens).max() ?? 0, 1)
    }

    private var axisDates: [Date] {
        guard !timeline.isEmpty else { return [] }
        let preferredCount = compact ? (period == .week ? 4 : 5) : (period == .week ? 7 : 6)
        guard timeline.count > preferredCount else { return timeline.map(\.startDate) }

        let step = max(Int(ceil(Double(timeline.count - 1) / Double(preferredCount - 1))), 1)
        var values = stride(from: 0, to: timeline.count, by: step).map { timeline[$0].startDate }
        if let last = timeline.last?.startDate, values.last != last {
            values.append(last)
        }
        return values
    }

    var body: some View {
        Chart(timeline) { bucket in
            BarMark(
                x: .value("时间", bucket.startDate),
                y: .value("令牌", bucket.totalTokens)
            )
            .foregroundStyle(AppColors.metricPrimary)
            .opacity(bucket.totalTokens > 0 ? 1 : 0.22)
        }
        .chartLegend(.hidden)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(AppColors.neutral.opacity(compact ? 0.08 : 0.12))
                AxisTick()
                    .foregroundStyle(AppColors.neutral.opacity(compact ? 0.14 : 0.18))
                AxisValueLabel {
                    if let date = value.as(Date.self), let bucket = timeline.first(where: { $0.startDate == date }) {
                        Text(bucket.label)
                            .font(compact ? AppTypography.nano : AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    }
                }
            }
        }
        .chartYScale(domain: 0...maxTokens)
        .frame(height: compact ? 96 : 220)
        .padding(.horizontal, compact ? Spacing.xxs : Spacing.xs)
        .padding(.vertical, compact ? Spacing.xxs : Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: compact ? AppRadius.md : AppRadius.card)
                .fill(AppColors.tintedBackground(AppColors.metricPrimary, opacity: compact ? 0.06 : 0.08))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let peak = timeline.max { $0.totalTokens < $1.totalTokens }
        let peakText = peak.map { "峰值 \(Formatters.tokens($0.totalTokens))，时间 \($0.label)" } ?? "暂无峰值"
        return "令牌时间线柱状图，\(period.label)，共 \(timeline.count) 个时间桶，\(peakText)"
    }
}

/// Donut chart + cache gauge + cost-by-model bar.
struct TokenChartSection: View {
    let usage: TokenUsage

    private var paidModels: [TokenUsage.ModelUsage] {
        usage.byModel.filter { $0.costUsd > 0 }
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                tokenDonut
                Spacer()
                RingGauge(
                    value: usage.totals.cacheHitRate,
                    label: "缓存命中",
                    color: AppColors.metricHighlight
                )
            }

            if !paidModels.isEmpty {
                costByModelChart
            }
        }
    }

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

    private var costByModelChart: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("按模型统计成本")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.neutral)

            Chart(paidModels) { model in
                BarMark(
                    x: .value("成本", model.costUsd),
                    y: .value("模型", Formatters.modelShortName(model.fullModel))
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
