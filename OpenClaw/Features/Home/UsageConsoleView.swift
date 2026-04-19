import SwiftUI

/// Usage 统计控制台 — 对齐 Web 端 `/usage` 路由：
/// 展示聚合用量数据，支持按用户、按模型、按时间段筛选。
struct UsageConsoleView: View {
    let adminVM: AdminViewModel

    @State private var period: Period = .month
    @State private var groupBy: GroupBy = .user
    @State private var loading = false
    @State private var aggregateUsage: [AdminUsageEntryDTO] = []
    @State private var summary: AdminUsageSummaryDTO?
    @State private var error: String?

    enum Period: String, CaseIterable {
        case day, week, month
        var label: String {
            switch self {
            case .day: return "今日"
            case .week: return "本周"
            case .month: return "本月"
            }
        }
    }

    enum GroupBy: String, CaseIterable {
        case user, model
        var label: String {
            switch self {
            case .user: return "按用户"
            case .model: return "按模型"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let s = summary {
                    summaryStrip(s)
                }

                filtersBar

                if loading {
                    ProgressView("加载中…")
                        .padding(.top, Spacing.xl)
                } else if let err = error {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(err)
                    )
                } else if aggregateUsage.isEmpty {
                    ContentUnavailableView(
                        "暂无用量数据",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("选择的时间段内没有 LLM 调用记录。")
                    )
                } else {
                    usageList
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "用量统计") {
                    Text(subtitle)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
        .refreshable {
            await load()
            Haptics.shared.refreshComplete()
        }
        .task {
            if aggregateUsage.isEmpty && !loading {
                await load()
            }
        }
    }

    private var subtitle: String {
        "\(period.label) · \(groupBy.label)"
    }

    // MARK: - Summary strip

    @ViewBuilder
    private func summaryStrip(_ s: AdminUsageSummaryDTO) -> some View {
        HStack(spacing: Spacing.sm) {
            statTile(
                icon: "person.2.fill",
                value: "\(s.users?.total ?? 0)",
                label: "用户",
                tint: AppColors.metricPrimary
            )
            statTile(
                icon: "cpu",
                value: "\(s.usage30d?.llmCalls ?? 0)",
                label: "调用",
                tint: AppColors.metricTertiary
            )
            statTile(
                icon: "dollarsign.circle.fill",
                value: formatCost(s.usage30d?.totalCost),
                label: "成本",
                tint: AppColors.metricWarm
            )
        }
    }

    @ViewBuilder
    private func statTile(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(tint.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(tint)
                Text(label)
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
            Spacer()
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Filters

    @ViewBuilder
    private var filtersBar: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text("时间段")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
                Spacer()
                ForEach(Period.allCases, id: \.rawValue) { p in
                    Button {
                        period = p
                        Task { await load() }
                        Haptics.shared.success()
                    } label: {
                        Text(p.label)
                            .font(AppTypography.nano)
                            .fontWeight(.semibold)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(period == p ? AppColors.primaryAction : AppColors.primaryAction.opacity(0.08))
                            )
                            .foregroundStyle(period == p ? Color.white : AppColors.primaryAction)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: Spacing.xs) {
                Text("分组")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
                Spacer()
                ForEach(GroupBy.allCases, id: \.rawValue) { g in
                    Button {
                        groupBy = g
                        Haptics.shared.success()
                    } label: {
                        Text(g.label)
                            .font(AppTypography.nano)
                            .fontWeight(.semibold)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(groupBy == g ? AppColors.info : AppColors.info.opacity(0.08))
                            )
                            .foregroundStyle(groupBy == g ? Color.white : AppColors.info)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Usage list

    @ViewBuilder
    private var usageList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(AppColors.metricPrimary)
                Text("用量明细")
                    .font(AppTypography.captionBold)
                Spacer()
                Text("\(aggregateUsage.count) 条")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(Array(aggregateUsage.enumerated()), id: \.offset) { _, entry in
                    usageRow(entry)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    @ViewBuilder
    private func usageRow(_ entry: AdminUsageEntryDTO) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 1) {
                Text(groupBy == .user ? (entry.userId ?? "系统") : entry.model)
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if groupBy == .user {
                    Text(entry.model)
                        .font(AppTypography.captionMono)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: Spacing.xs) {
                    Label("\(entry.callCount ?? 0)", systemImage: "arrow.triangle.2.circlepath")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                    Label(formatTokens(entry.inputTokens ?? 0), systemImage: "arrow.down")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                    Label(formatTokens(entry.outputTokens ?? 0), systemImage: "arrow.up")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                }
            }
            Spacer()
            Text(formatCost(entry.totalCost))
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.metricWarm)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color(.systemGroupedBackground))
        )
    }

    // MARK: - Helpers

    private func formatCost(_ raw: String?) -> String {
        guard let s = raw, let v = Double(s) else { return "$0.00" }
        return String(format: "$%.2f", v)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return String(n)
    }

    // MARK: - Data

    private func load() async {
        loading = true
        defer { loading = false }
        error = nil

        async let usageTask: AdminUsageResponseDTO? = try? adminVM.loadAggregateUsage(period: period.rawValue)
        async let summaryTask: AdminUsageSummaryDTO? = try? adminVM.loadAdminSummary()

        let usage = await usageTask
        let sum = await summaryTask

        if let usage {
            aggregateUsage = usage.usage ?? []
            // Sort by cost descending
            aggregateUsage.sort { a, b in
                let aVal = Double(a.totalCost ?? "0") ?? 0
                let bVal = Double(b.totalCost ?? "0") ?? 0
                return aVal > bVal
            }
        } else {
            error = "无法加载用量数据"
        }

        summary = sum
    }
}
