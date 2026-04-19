import SwiftUI

/// 任务（异步 Job）控制台 — 对齐 Web UI 的「Jobs」：
///   - /api/jobs 列表（state=pending/in_progress/completed/failed/stuck）
///   - /api/jobs/summary 汇总
///   - /api/jobs/{id} 详情（侧拉）
struct JobsConsoleView: View {
    @State var vm: JobsViewModel
    @State private var filter: JobStateFilter = .all
    @State private var detailId: String?

    private var filteredJobs: [JobDTO] {
        switch filter {
        case .all: return vm.jobs
        case .pending: return vm.jobs.filter { ($0.state ?? "") == "pending" }
        case .inProgress: return vm.jobs.filter { ($0.state ?? "") == "in_progress" }
        case .completed: return vm.jobs.filter { ($0.state ?? "") == "completed" }
        case .failed: return vm.jobs.filter { ["failed", "stuck"].contains($0.state ?? "") }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                summaryStrip
                filterPicker
                jobsList
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "任务") {
                    Text(subtitle)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
        .refreshable {
            await vm.load()
            Haptics.shared.refreshComplete()
        }
        .task {
            if vm.jobs.isEmpty && !vm.isLoading { await vm.load() }
        }
        .sheet(item: Binding(get: { detailId.map { JobIdentifier(id: $0) } }, set: { detailId = $0?.id })) { ident in
            JobDetailSheet(jobId: ident.id, vm: vm) { detailId = nil }
        }
    }

    private var subtitle: String {
        if let s = vm.summary {
            return "\(s.total) 总 · 进行中 \(s.inProgress) · 完成 \(s.completed) · 失败 \(s.failed + s.stuck)"
        }
        return "异步任务"
    }

    // MARK: - Summary strip

    @ViewBuilder
    private var summaryStrip: some View {
        if let s = vm.summary {
            HStack(spacing: Spacing.sm) {
                summaryTile(icon: "clock.fill", value: "\(s.pending)", label: "待处理", tint: AppColors.warning)
                summaryTile(icon: "arrow.triangle.2.circlepath", value: "\(s.inProgress)", label: "执行中", tint: AppColors.info)
                summaryTile(icon: "checkmark.seal.fill", value: "\(s.completed)", label: "已完成", tint: AppColors.success)
                summaryTile(icon: "exclamationmark.triangle.fill", value: "\(s.failed + s.stuck)", label: "异常", tint: AppColors.danger)
            }
        }
    }

    @ViewBuilder
    private func summaryTile(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(AppTypography.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(AppTypography.cardTitle)
                .foregroundStyle(tint)
            Text(label)
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Filter picker

    @ViewBuilder
    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(JobStateFilter.allCases) { f in
                    Button {
                        filter = f
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: f.icon)
                                .font(AppTypography.nano)
                            Text(f.label)
                                .font(AppTypography.caption)
                        }
                        .foregroundStyle(filter == f ? Color.white : AppColors.neutral)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(filter == f ? AppColors.primaryAction : AppColors.neutral.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Jobs list

    @ViewBuilder
    private var jobsList: some View {
        if filteredJobs.isEmpty && !vm.isLoading {
            ContentUnavailableView(
                "没有任务",
                systemImage: "tray",
                description: Text(filter == .all ? "尚未创建任何异步任务。" : "没有符合当前筛选的任务。")
            )
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(filteredJobs) { job in
                    Button {
                        detailId = job.id
                    } label: {
                        jobRow(job)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color(.systemBackground))
            )
        }
    }

    @ViewBuilder
    private func jobRow(_ job: JobDTO) -> some View {
        let tint = color(forState: job.state)
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(tint.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: icon(forState: job.state))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title ?? job.id)
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack(spacing: Spacing.xxs) {
                    Text((job.state ?? "unknown").capitalized)
                        .font(AppTypography.nano)
                        .padding(.horizontal, Spacing.xxs)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(tint.opacity(0.15)))
                        .foregroundStyle(tint)
                    if let user = job.userId, !user.isEmpty {
                        Text("·  \(user)")
                            .font(AppTypography.nano)
                            .foregroundStyle(AppColors.neutral)
                    }
                    if let created = prettyTime(job.createdAt) {
                        Text("·  \(created)")
                            .font(AppTypography.nano)
                            .foregroundStyle(AppColors.neutral)
                    }
                }
                Text(job.id)
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color(.systemGroupedBackground))
        )
    }

    private func color(forState state: String?) -> Color {
        switch (state ?? "").lowercased() {
        case "completed":   return AppColors.success
        case "in_progress": return AppColors.info
        case "pending":     return AppColors.warning
        case "failed":      return AppColors.danger
        case "stuck":       return AppColors.danger
        default:            return AppColors.neutral
        }
    }

    private func icon(forState state: String?) -> String {
        switch (state ?? "").lowercased() {
        case "completed":   return "checkmark.seal.fill"
        case "in_progress": return "arrow.triangle.2.circlepath"
        case "pending":     return "clock.fill"
        case "failed":      return "xmark.octagon.fill"
        case "stuck":       return "exclamationmark.triangle.fill"
        default:            return "circle.dashed"
        }
    }

    private func prettyTime(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return nil }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }

    private enum JobStateFilter: String, CaseIterable, Identifiable {
        case all, pending, inProgress, completed, failed

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all:        "全部"
            case .pending:    "待处理"
            case .inProgress: "执行中"
            case .completed:  "已完成"
            case .failed:     "异常"
            }
        }

        var icon: String {
            switch self {
            case .all:        "tray.full"
            case .pending:    "clock"
            case .inProgress: "arrow.triangle.2.circlepath"
            case .completed:  "checkmark.seal"
            case .failed:     "exclamationmark.triangle"
            }
        }
    }

    private struct JobIdentifier: Identifiable {
        let id: String
    }
}

// MARK: - Detail sheet

private struct JobDetailSheet: View {
    let jobId: String
    @Bindable var vm: JobsViewModel
    let onClose: () -> Void

    @State private var detail: JobDetailDTO?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            List {
                if let detail {
                    Section("基本信息") {
                        LabeledContent("ID") { Text(detail.id).font(AppTypography.captionMono).lineLimit(1).truncationMode(.middle) }
                        if let title = detail.title, !title.isEmpty { LabeledContent("标题", value: title) }
                        if let state = detail.state { LabeledContent("状态", value: state.capitalized) }
                        if let user = detail.userId, !user.isEmpty { LabeledContent("用户", value: user) }
                        if let c = detail.createdAt { LabeledContent("创建", value: c) }
                        if let s = detail.startedAt { LabeledContent("开始", value: s) }
                        if let f = detail.finishedAt { LabeledContent("完成", value: f) }
                    }

                    if let prompt = detail.prompt, !prompt.isEmpty {
                        Section("提示词") {
                            Text(prompt).font(AppTypography.captionMono).textSelection(.enabled)
                        }
                    }
                    if let result = detail.result, !result.isEmpty {
                        Section("结果") {
                            Text(result).font(AppTypography.captionMono).textSelection(.enabled)
                        }
                    }
                    if let err = detail.error, !err.isEmpty {
                        Section("错误") {
                            Text(err).font(AppTypography.captionMono).foregroundStyle(AppColors.danger).textSelection(.enabled)
                        }
                    }
                } else if let loadError {
                    Section("加载失败") {
                        Text(loadError).foregroundStyle(AppColors.danger).textSelection(.enabled)
                    }
                } else {
                    Section {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                }
            }
            .navigationTitle("任务详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭", action: onClose)
                }
            }
            .task {
                do {
                    detail = try await vm.jobDetail(id: jobId)
                } catch {
                    loadError = error.localizedDescription
                }
            }
        }
    }
}
