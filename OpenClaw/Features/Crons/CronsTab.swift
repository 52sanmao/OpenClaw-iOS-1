import SwiftUI

struct CronsTab: View {
    let vm: CronSummaryViewModel
    let detailRepository: CronDetailRepository
    let client: GatewayClientProtocol

    @State private var selectedTab: CronTab = .jobs
    @State private var historyVM: CronHistoryViewModel?
    @State private var jobToRun: CronJob?
    @State private var pendingJobToggle: PendingJobToggle?
    @State private var triggerError: Error?
    @State private var updatingJobIDs: Set<String> = []

    private var jobs: [CronJob] { vm.data ?? [] }

    private var jobNameMap: [String: String] {
        Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0.name) })
    }

    enum CronTab: String, CaseIterable {
        case jobs = "定时任务"
        case history = "历史"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视图", selection: $selectedTab) {
                    ForEach(CronTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

                switch selectedTab {
                case .jobs:
                    jobsList
                case .history:
                    historyList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DetailTitleView(title: "定时任务") {
                        cronSubtitle
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ScheduleTimelineView(jobs: jobs)
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .alert("手动运行？", isPresented: Binding(
                get: { jobToRun != nil },
                set: { if !$0 { jobToRun = nil } }
            )) {
                Button("运行", role: .destructive) {
                    guard let job = jobToRun else { return }
                    Task { await triggerRun(job) }
                }
                Button("取消", role: .cancel) { jobToRun = nil }
            } message: {
                if let job = jobToRun {
                    Text("这将立即在正常计划之外触发 \"\(job.name)\"。")
                }
            }
        }
        .alert("启停任务？", isPresented: Binding(
            get: { pendingJobToggle != nil },
            set: { if !$0 { pendingJobToggle = nil } }
        )) {
            Button(toggleConfirmationTitle, role: pendingJobToggle?.enabled == false ? .destructive : nil) {
                guard let toggle = pendingJobToggle else { return }
                pendingJobToggle = nil
                Task { await setJobEnabled(toggle.job, enabled: toggle.enabled) }
            }
            Button("取消", role: .cancel) { pendingJobToggle = nil }
        } message: {
            if let toggle = pendingJobToggle {
                Text(toggleConfirmationMessage(for: toggle))
            }
        }
        .alert("运行失败", isPresented: Binding(
            get: { triggerError != nil },
            set: { if !$0 { triggerError = nil } }
        )) {
            Button("确定") { triggerError = nil }
        } message: {
            if let err = triggerError {
                Text(err.localizedDescription)
            }
        }
        .task { vm.start() }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .history, historyVM == nil {
                let hvm = CronHistoryViewModel(
                    repository: detailRepository,
                    jobsProvider: { [vm] in vm.data ?? [] }
                )
                historyVM = hvm
                Task { await hvm.loadRuns() }
            }
        }
    }

    // MARK: - Subtitle

    @ViewBuilder
    private var cronSubtitle: some View {
        if !jobs.isEmpty {
            let failed = jobs.filter { $0.status == .failed }.count
            HStack(spacing: Spacing.xs) {
                Text("\(jobs.count) 个任务")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                if failed > 0 {
                    Text("\u{00B7} \(failed) 个失败")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.danger)
                }
            }
        }
    }

    // MARK: - Jobs List

    @ViewBuilder
    private var jobsList: some View {
        if !jobs.isEmpty {
            List {
                Section("定时任务") {
                ForEach(jobs) { job in
                CronJobRow(
                    job: job,
                    isUpdating: updatingJobIDs.contains(job.id),
                    onToggleEnabled: { newValue in
                        pendingJobToggle = PendingJobToggle(job: job, enabled: newValue)
                    },
                    onRun: { jobToRun = job }
                )
                    .background(
                        NavigationLink("", destination: CronDetailView(
                            vm: CronDetailViewModel(
                                job: job,
                                repository: detailRepository,
                                client: client,
                                store: InvestigationStore(),
                                onJobUpdated: { await vm.refresh() }
                            ),
                            repository: detailRepository
                        ))
                        .opacity(0)
                    )
                }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await vm.refresh()
                Haptics.shared.refreshComplete()
            }
        } else if vm.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.error {
            ContentUnavailableView(
                "不可用",
                systemImage: "wifi.exclamationmark",
                description: Text(err.localizedDescription)
            )
        } else {
            ContentUnavailableView(
                "没有定时任务",
                systemImage: "clock.arrow.2.circlepath",
                description: Text("IronClaw 服务上未配置任何定时任务。")
            )
        }
    }

    // MARK: - History List

    @ViewBuilder
    private var historyList: some View {
        if let hvm = historyVM {
            if hvm.isLoading && hvm.runs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hvm.runs.isEmpty && !hvm.isLoading {
                ContentUnavailableView(
                    "没有历史",
                    systemImage: "clock",
                    description: Text("尚未记录任何运行。")
                )
            } else if let err = hvm.error, hvm.runs.isEmpty {
                ContentUnavailableView(
                    "不可用",
                    systemImage: "wifi.exclamationmark",
                    description: Text(err.localizedDescription)
                )
            } else {
                List {
                    Section("运行历史") {
                    ForEach(hvm.runs) { run in
                        CronHistoryRow(run: run, jobName: jobNameMap[run.jobId])
                            .background(
                                Group {
                                    if run.sessionKey != nil || run.sessionId != nil {
                                        NavigationLink("", destination: SessionTraceView(run: run, repository: detailRepository, jobName: jobNameMap[run.jobId], client: client))
                                            .opacity(0)
                                    }
                                }
                            )
                    }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await hvm.loadRuns()
                    Haptics.shared.refreshComplete()
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    private func triggerRun(_ job: CronJob) async {
        do {
            try await detailRepository.triggerRun(jobId: job.id)
            Haptics.shared.success()
            await vm.refresh()
        } catch {
            triggerError = error
            Haptics.shared.error()
        }
    }

    private func setJobEnabled(_ job: CronJob, enabled: Bool) async {
        guard !updatingJobIDs.contains(job.id) else { return }
        updatingJobIDs.insert(job.id)
        defer { updatingJobIDs.remove(job.id) }

        do {
            try await detailRepository.setEnabled(jobId: job.id, enabled: enabled)
            await vm.refresh()
            Haptics.shared.success()
        } catch {
            triggerError = error
            Haptics.shared.error()
        }
    }

    private var toggleConfirmationTitle: String {
        pendingJobToggle?.enabled == true ? "启用" : "停用"
    }

    private func toggleConfirmationMessage(for toggle: PendingJobToggle) -> String {
        if toggle.enabled {
            return "这会重新启用“\(toggle.job.name)”并恢复按计划执行。"
        }
        return "这会停用“\(toggle.job.name)”，后续不会再按计划自动运行。"
    }
}

private struct PendingJobToggle {
    let job: CronJob
    let enabled: Bool
}

// MARK: - Row

struct CronJobRow: View {
    let job: CronJob
    let isUpdating: Bool
    var onToggleEnabled: ((Bool) -> Void)? = nil
    var onRun: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs + 1) {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(job.enabled ? AppColors.success : AppColors.neutral)
                        .frame(width: 8, height: 8)

                    Text(job.name)
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Spacer(minLength: Spacing.xxs)

                    CronStatusBadge(status: job.status, style: .small)
                }

                Text(job.scheduleDescription)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.neutral)

                HStack(spacing: Spacing.sm) {
                    Label(job.lastRunFormatted, systemImage: "arrow.counterclockwise")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)

                    Label(job.nextRunFormatted, systemImage: "arrow.clockwise")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }

                if job.consecutiveErrors > 0 {
                    Label(
                    "\(job.consecutiveErrors) 个连续错误",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.danger)
                }
            }

            VStack(alignment: .trailing, spacing: Spacing.sm) {
                if let onToggleEnabled {
                    Toggle("", isOn: Binding(
                        get: { job.enabled },
                        set: { onToggleEnabled($0) }
                    ))
                    .labelsHidden()
                    .disabled(isUpdating)
                    .tint(AppColors.primaryAction)
                    .accessibilityLabel(job.enabled ? "停用 \(job.name)" : "启用 \(job.name)")
                }

                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else if let onRun {
                    Button {
                        onRun()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(AppTypography.actionIcon)
                            .foregroundStyle(AppColors.primaryAction)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("手动运行 \(job.name)")
                }
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
