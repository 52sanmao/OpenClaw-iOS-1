import SwiftUI

struct TokenDetailView: View {
    @Bindable var vm: TokenUsageViewModel
    let detailRepository: CronDetailRepository
    @State private var pipelineVM: PipelineTokenViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Picker("周期", selection: $vm.selectedPeriod) {
                    ForEach(TokenPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.selectedPeriod) {
                    Task {
                        await vm.refresh()
                        await loadPipelines()
                    }
                }

                if let usage = vm.data {
                    section("时间线") {
                        TokenTimelinePanel(usage: usage, period: vm.selectedPeriod)
                    }

                    section("概览") {
                        TokenSummaryGrid(totals: usage.totals)
                    }

                    section("更多图表") {
                        TokenChartSection(usage: usage)
                    }

                    if !usage.byModel.isEmpty {
                        section("按模型查看（\(usage.byModel.count)）") {
                            ModelDetailSection(models: usage.byModel)
                        }
                    }

                    section("按流水线查看") {
                        PipelineBreakdownSection(
                            breakdown: pipelineVM?.breakdown,
                            totalTokens: usage.totals.totalTokens,
                            isLoading: pipelineVM?.isLoading ?? false,
                            error: pipelineVM?.error
                        )
                    }
                } else if vm.isLoading {
                    CardLoadingView(minHeight: 200)
                } else if let err = vm.error {
                    CardErrorView(error: err, minHeight: 100)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "令牌用量") {
                    if let usage = vm.data {
                        Text("\(Formatters.tokens(usage.totals.totalTokens)) · \(vm.selectedPeriod.label)")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    } else if vm.isLoading {
                        Text("加载中…")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    } else {
                        Text(vm.selectedPeriod.label)
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    }
                }
            }
        }
        .refreshable {
            await vm.refresh()
            await loadPipelines()
            Haptics.shared.refreshComplete()
        }
        .task {
            if vm.data == nil {
                await vm.refresh()
            }
            await loadPipelines()
        }
    }

    private func loadPipelines() async {
        guard let usage = vm.data else { return }
        if pipelineVM == nil {
            pipelineVM = PipelineTokenViewModel(repository: detailRepository)
        }
        await pipelineVM?.load(period: vm.selectedPeriod, totalTokens: usage.totals.totalTokens)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(AppTypography.cardTitle)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
