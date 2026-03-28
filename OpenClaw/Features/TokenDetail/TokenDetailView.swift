import SwiftUI

struct TokenDetailView: View {
    @Bindable var vm: TokenUsageViewModel
    let detailRepository: CronDetailRepository
    @State private var pipelineVM: PipelineTokenViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Period picker
                Picker("Period", selection: $vm.selectedPeriod) {
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
                    // Section 1: Summary grid
                    section("Overview") {
                        TokenSummaryGrid(totals: usage.totals)
                    }

                    // Section 2: Charts
                    section("Charts") {
                        TokenChartSection(usage: usage)
                    }

                    // Section 3: By Model
                    if !usage.byModel.isEmpty {
                        section("By Model (\(usage.byModel.count))") {
                            ModelDetailSection(models: usage.byModel)
                        }
                    }

                    // Section 4: By Pipeline
                    section("By Pipeline") {
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
        .navigationTitle("Token Usage")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await vm.refresh()
            await loadPipelines()
            Haptics.shared.refreshComplete()
        }
        .task {
            if vm.data == nil { vm.start() }
            await loadPipelines()
        }
    }

    // MARK: - Helpers

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
