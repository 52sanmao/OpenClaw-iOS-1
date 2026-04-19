import SwiftUI

/// 扩展控制台 — 配置档 banner + 工具分组卡 + allow/deny 芯片。
struct ExtensionsConsoleView: View {
    let vm: ToolsConfigViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let config = vm.config {
                    profileBanner(config)
                    policyChips(config)
                    groupsStack(config)
                    mcpSummary
                } else if vm.isLoading {
                    CardLoadingView(minHeight: 180)
                } else if let error = vm.error {
                    CardErrorView(error: error, minHeight: 140)
                } else {
                    ContentUnavailableView(
                        "暂无扩展配置",
                        systemImage: "puzzlepiece.extension",
                        description: Text("检查网关的 tools-list 扩展接口。")
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "扩展") {
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
    }

    private var subtitle: String {
        guard let config = vm.config else { return "工具配置与扩展能力" }
        let toolCount = config.groups.reduce(0) { $0 + $1.tools.count }
        return "\(config.profile.capitalized) · \(toolCount) 个工具 · \(vm.mcpServers.count) MCP"
    }

    // MARK: - Profile banner

    @ViewBuilder
    private func profileBanner(_ config: ToolsConfig) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(config.profileColor.opacity(0.18), lineWidth: 6)
                    .frame(width: 58, height: 58)
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(config.profileColor)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(config.profile.capitalized)
                        .font(AppTypography.cardTitle)
                    Text("配置档")
                        .font(AppTypography.micro)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(config.profileColor.opacity(0.14)))
                        .foregroundStyle(config.profileColor)
                }
                Text(profileDescription(config.profile))
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(config.profileColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func profileDescription(_ profile: String) -> String {
        switch profile {
        case "full":      "全量工具 — 包含运行时、文件系统、网络、消息、记忆等全部能力。"
        case "coding":    "编码优先 — 面向开发任务的精简工具集。"
        case "messaging": "消息优先 — 只开放聊天与通知相关工具。"
        case "minimal":   "最小集合 — 只有核心调度与记忆工具。"
        default:          "当前配置档的详细描述未定义。"
        }
    }

    // MARK: - Allow/Deny chips

    @ViewBuilder
    private func policyChips(_ config: ToolsConfig) -> some View {
        if config.allow.isEmpty && config.deny.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if !config.allow.isEmpty {
                    chipRow(icon: "checkmark.shield.fill", label: "允许", items: config.allow, tint: AppColors.success)
                }
                if !config.deny.isEmpty {
                    chipRow(icon: "xmark.shield.fill", label: "拒绝", items: config.deny, tint: AppColors.danger)
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
    private func chipRow(icon: String, label: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(AppTypography.nano)
                    .foregroundStyle(tint)
                Text(label)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(tint)
                Text("\(items.count) 项")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
            FlowLayout(spacing: Spacing.xxs) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(AppTypography.nano)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(tint.opacity(0.10)))
                        .foregroundStyle(tint)
                }
            }
        }
    }

    // MARK: - Groups

    @ViewBuilder
    private func groupsStack(_ config: ToolsConfig) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(AppColors.metricWarm)
                Text("原生工具组")
                    .font(AppTypography.captionBold)
                Spacer()
                Text("\(config.groups.count) 组")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            VStack(spacing: Spacing.sm) {
                ForEach(config.groups) { group in
                    groupCard(group)
                }
            }
        }
    }

    @ViewBuilder
    private func groupCard(_ group: ToolsConfig.ToolGroup) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(AppColors.metricWarm.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: group.icon)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.metricWarm)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name)
                        .font(AppTypography.captionBold)
                    Text("\(group.tools.count) 个工具")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                }
                Spacer()
            }

            FlowLayout(spacing: Spacing.xxs) {
                ForEach(group.tools) { tool in
                    Text(tool.name)
                        .font(AppTypography.captionMono)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(AppColors.metricWarm.opacity(0.08))
                        )
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - MCP summary

    @ViewBuilder
    private var mcpSummary: some View {
        if vm.mcpServers.isEmpty { EmptyView() } else {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(AppColors.metricHighlight.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "server.rack")
                        .foregroundStyle(AppColors.metricHighlight)
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("MCP 服务器")
                        .font(AppTypography.captionBold)
                    Text("\(vm.mcpServers.count) 个 — 在「连接 · MCP 服务」页查看工具清单")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color(.systemBackground))
            )
        }
    }
}

// MARK: - Flow layout (simple wrap)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if rowWidth + s.width > maxWidth && rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let s = view.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
