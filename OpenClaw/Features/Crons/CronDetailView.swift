import SwiftUI

struct CronDetailView: View {
    @State var vm: CronDetailViewModel
    let repository: CronDetailRepository
    @State private var expandedRunId: String?
    @State private var showRunConfirmation = false
    @State private var showDisableConfirmation = false
    @State private var showInvestigation = false
    @State private var showPreviousInvestigation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // MARK: - About (merged: schedule + timing + config)
            Section("关于") {
                // Task description
                if let task = vm.job.taskDescription {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("用途")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                        Text(task)
                            .font(AppTypography.caption)
                    }
                }

                // Configured model
                if let model = vm.job.configuredModel {
                    LabeledContent("模型") {
                        ModelPill(model: model)
                    }
                }

                // Schedule
                LabeledContent("频率", value: vm.job.scheduleDescription)
                LabeledContent("表达式") {
                    Text(vm.job.scheduleExpr)
                        .font(AppTypography.captionMono)
                        .foregroundStyle(AppColors.neutral)
                }
                if let tz = vm.job.timeZone {
                    LabeledContent("时区", value: tz)
                }

                // Timing
                LabeledContent("上次运行") {
                    HStack(spacing: Spacing.xxs) {
                        CronStatusDot(status: vm.job.status)
                        Text(vm.job.lastRunFormatted)
                            .font(AppTypography.body)
                    }
                }
                LabeledContent("下次运行") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(vm.job.nextRunFormatted)
                            .font(AppTypography.body)
                        if let nextRun = vm.job.nextRun {
                            Text(Formatters.absoluteString(for: nextRun))
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColors.neutral)
                        }
                    }
                }
                if vm.job.consecutiveErrors > 0 {
                    LabeledContent("连续错误") {
                        Text("\(vm.job.consecutiveErrors)")
                            .foregroundStyle(AppColors.danger)
                            .fontWeight(.semibold)
                    }
                }
            }

            // MARK: - Error + Investigate
            if let error = vm.job.lastError {
                Section("错误") {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)

                    Button {
                        showInvestigation = true
                        Task { await vm.investigateError() }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(AppTypography.body)
                            Text("用 AI 排查")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .foregroundStyle(.white)
                        .background(AppColors.metricTertiary, in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    }
                    .disabled(vm.isInvestigating)

                    if let prev = vm.previousInvestigation {
                        Button {
                            showPreviousInvestigation = true
                        } label: {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(AppTypography.micro)
                                Text("上次排查于 \(prev.investigatedAtFormatted)")
                                    .font(AppTypography.micro)
                                    .underline()
                            }
                            .foregroundStyle(AppColors.primaryAction)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // MARK: - Operation Errors
            if let runtimeError = vm.error {
                Section("操作错误") {
                    Text(runtimeError.localizedDescription)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)

                    Text("如果这里报错，而聊天页仍可使用，通常表示是 routines 接口本身失败，而不是整个 App 不可用。")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }

            // MARK: - Run Stats
            if let stats = vm.stats {
                CronStatsSection(stats: stats)
            }

            // MARK: - Run History
            Section {
                if vm.isLoading && vm.runs.isEmpty {
                    CardLoadingView(minHeight: 60)
                } else if vm.runs.isEmpty && !vm.isLoading {
                    ContentUnavailableView(
                        "暂无运行记录",
                        systemImage: "clock",
                        description: Text("这个任务还没有产生任何运行记录。")
                    )
                    .frame(minHeight: 100)
                } else {
                    ForEach(vm.runs) { run in
                        CronRunRow(run: run, isExpanded: expandedRunId == run.id) {
                            withAnimation(.snappy(duration: 0.3)) {
                                expandedRunId = expandedRunId == run.id ? nil : run.id
                            }
                        }
                        .background(
                            Group {
                                if run.sessionKey != nil || run.sessionId != nil {
                                    NavigationLink("", destination: SessionTraceView(run: run, repository: repository, jobName: vm.job.name, client: vm.client))
                                        .opacity(0)
                                }
                            }
                        )
                    }

                    if vm.hasMore {
                        Button {
                            Task { await vm.loadMore() }
                        } label: {
                            HStack {
                                Spacer()
                                if vm.isLoadingMore {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Text("加载更多")
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColors.primaryAction)
                                }
                                Spacer()
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                        .disabled(vm.isLoadingMore)
                    }
                }
            } header: {
                HStack {
                    Text("运行历史")
                    if let total = vm.totalRuns {
                        Text("(共 \(total) 条)")
                            .foregroundStyle(AppColors.neutral)
                    } else if !vm.runs.isEmpty {
                        Text("(\(vm.runs.count))")
                            .foregroundStyle(AppColors.neutral)
                    }
                    Spacer()
                    if vm.isLoading && !vm.runs.isEmpty {
                        ProgressView().scaleEffect(0.7)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Custom title with status subtitle
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: vm.job.name) {
                    CronStatusBadge(status: vm.job.status, style: .small)
                }
            }

            // Run Now + Enable/Disable
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Spacing.sm) {
                    // Enable/Disable
                    Button {
                        showDisableConfirmation = true
                    } label: {
                        if vm.isTogglingEnabled {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: vm.job.enabled ? "pause.circle" : "play.circle")
                                .foregroundStyle(vm.job.enabled ? AppColors.warning : AppColors.success)
                        }
                    }

                    // Run Now
                    Button {
                        showRunConfirmation = true
                    } label: {
                        if vm.isTriggering {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "play.fill")
                                .foregroundStyle(AppColors.primaryAction)
                        }
                    }
                }
            }
        }
        .alert("立即运行？", isPresented: $showRunConfirmation) {
            Button("运行", role: .destructive) {
                Task { await vm.triggerRun() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会立刻触发“\(vm.job.name)”运行，不再等待原定计划时间。")
        }
        .alert(
            vm.job.enabled ? "禁用任务？" : "启用任务？",
            isPresented: $showDisableConfirmation
        ) {
            Button(vm.job.enabled ? "禁用" : "启用", role: vm.job.enabled ? .destructive : nil) {
                let wasEnabled = vm.job.enabled
                Task {
                    await vm.toggleEnabled()
                    if wasEnabled { dismiss() }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(vm.job.enabled
                 ? "禁用后，“\(vm.job.name)”将停止按计划自动运行，直到你重新启用它。"
                 : "启用后，“\(vm.job.name)”会恢复按正常计划运行。")
        }
        .refreshable {
            await vm.loadRuns()
            Haptics.shared.refreshComplete()
        }
        .sheet(isPresented: $showInvestigation) {
            InvestigateSheet(vm: vm)
        }
        .sheet(isPresented: $showPreviousInvestigation) {
            if let prev = vm.previousInvestigation {
                SavedInvestigationSheet(investigation: prev)
            }
        }
        .task {
            await vm.loadRuns()
        }
    }
}
