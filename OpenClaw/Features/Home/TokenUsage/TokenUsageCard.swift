import SwiftUI

struct TokenUsageCard: View {
    @Bindable var vm: TokenUsageViewModel
    var detailRepository: CronDetailRepository?

    var body: some View {
        CardContainer(
            title: "Token Usage",
            systemImage: "number.circle",
            isStale: vm.isStale,
            isLoading: vm.isLoading && vm.data == nil
        ) {
            if let usage = vm.data {
                VStack(spacing: Spacing.sm) {
                    // Period picker
                    Picker("Period", selection: $vm.selectedPeriod) {
                        ForEach(TokenPeriod.allCases) { period in
                            Text(period.label).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.selectedPeriod) {
                        Task { await vm.refresh() }
                    }

                    // Hero row: total + cost
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Formatters.tokens(usage.totals.totalTokens))
                                .font(AppTypography.heroNumber)
                                .contentTransition(.numericText())
                            Text("total tokens")
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColors.neutral)
                        }
                        Spacer()
                        if usage.totals.costUsd > 0 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Formatters.cost(usage.totals.costUsd))
                                    .font(AppTypography.metricValue)
                                    .foregroundStyle(AppColors.metricWarm)
                                    .contentTransition(.numericText())
                                Text("cost")
                                    .font(AppTypography.micro)
                                    .foregroundStyle(AppColors.neutral)
                            }
                        }
                    }

                    // Token breakdown bar (input/output/cache)
                    TokenUsageBar(totals: usage.totals)

                    // Stats grid
                    TokenStatsGrid(totals: usage.totals)

                    // Model breakdown — behind show more
                    if !usage.byModel.isEmpty {
                        ModelBreakdownSection(models: usage.byModel)
                    }

                    // Detail navigation
                    if let repo = detailRepository {
                        NavigationLink {
                            TokenDetailView(vm: vm, detailRepository: repo)
                        } label: {
                            HStack(spacing: Spacing.xxs) {
                                Text("View Details")
                                    .font(AppTypography.caption)
                                Image(systemName: "chevron.right")
                                    .font(AppTypography.micro)
                            }
                            .foregroundStyle(AppColors.primaryAction)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.xxs)
                        }
                    }
                }
            } else if vm.isLoading {
                CardLoadingView(minHeight: 120)
            } else if let err = vm.error {
                CardErrorView(error: err, minHeight: 80)
            }
        }
    }
}

// MARK: - Token Usage Bar

private struct TokenUsageBar: View {
    let totals: TokenUsage.Totals

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            GeometryReader { geo in
                let w = geo.size.width
                let total = max(totals.totalTokens, 1)
                HStack(spacing: 1) {
                    segment(totals.inputTokens, total, w, AppColors.metricPrimary)
                    segment(totals.outputTokens, total, w, AppColors.metricPositive)
                    segment(totals.cacheReadTokens, total, w, AppColors.metricHighlight)
                    segment(totals.cacheWriteTokens, total, w, AppColors.metricTertiary)
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            HStack(spacing: Spacing.sm) {
                TokenLegendItem(color: AppColors.metricPrimary, label: "In", value: totals.inputTokens)
                TokenLegendItem(color: AppColors.metricPositive, label: "Out", value: totals.outputTokens)
                TokenLegendItem(color: AppColors.metricHighlight, label: "Cache Read", value: totals.cacheReadTokens)
                TokenLegendItem(color: AppColors.metricTertiary, label: "Cache Write", value: totals.cacheWriteTokens)
                Spacer()
            }
        }
    }

    private func segment(_ value: Int, _ total: Int, _ width: CGFloat, _ color: Color) -> some View {
        let p = CGFloat(value) / CGFloat(total)
        return Rectangle().fill(color).frame(width: max(p * width, value > 0 ? 2 : 0))
    }
}

// MARK: - Stats Grid

private struct TokenStatsGrid: View {
    let totals: TokenUsage.Totals

    var body: some View {
        HStack(spacing: Spacing.sm) {
            StatPill(icon: "arrow.up.arrow.down", label: "Requests", value: "\(totals.requestCount)")
            StatPill(icon: "brain.head.profile", label: "Thinking", value: "\(totals.thinkingRequests)")
            StatPill(icon: "terminal", label: "Tool Use", value: "\(totals.toolRequests)")
            Spacer()
        }
    }
}

private struct StatPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(AppTypography.badgeIcon)
                .foregroundStyle(AppColors.neutral)
            Text(value)
                .font(AppTypography.captionBold)
                .contentTransition(.numericText())
            Text(label)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
        }
    }
}

// MARK: - Model Breakdown (collapsible)

private struct ModelBreakdownSection: View {
    let models: [TokenUsage.ModelUsage]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("By Model (\(models.count))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primaryAction)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.primaryAction)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(models) { model in
                    HStack(spacing: Spacing.xs) {
                        ModelPill(model: model.fullModel)

                        Spacer()

                        Text(Formatters.tokens(model.totalTokens))
                            .font(AppTypography.captionMono)
                            .foregroundStyle(AppColors.metricPrimary)

                        Text("\(model.requestCount) req")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    }
                }
            }
        }
    }
}
