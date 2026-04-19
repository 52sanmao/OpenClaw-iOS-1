import SwiftUI

/// 助手（代理）控制台 — 默认代理 spotlight + 代理资料网格。
struct AgentsConsoleView: View {
    let adminVM: AdminViewModel

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if !adminVM.agents.isEmpty {
                    if let primary = defaultAgent {
                        spotlight(primary)
                    }
                    agentsGrid
                } else if adminVM.isLoading {
                    CardLoadingView(minHeight: 180)
                } else if let error = adminVM.error {
                    CardErrorView(error: error, minHeight: 140)
                } else {
                    ContentUnavailableView(
                        "暂无代理",
                        systemImage: "person.2",
                        description: Text("检查网关的 agents-list 扩展接口。")
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
                DetailTitleView(title: "助手") {
                    Text(subtitle)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
        .refreshable {
            await adminVM.load()
            Haptics.shared.refreshComplete()
        }
        .task {
            if adminVM.agents.isEmpty && !adminVM.isLoading {
                await adminVM.load()
            }
        }
    }

    private var defaultAgent: AgentInfo? {
        adminVM.agents.first(where: { $0.isDefault })
    }

    private var otherAgents: [AgentInfo] {
        adminVM.agents.filter { !$0.isDefault }
    }

    private var subtitle: String {
        if adminVM.agents.isEmpty { return "代理编排" }
        let defaultName = defaultAgent?.name ?? "未指定"
        return "\(adminVM.agents.count) 个代理 · 默认 \(defaultName)"
    }

    // MARK: - Spotlight

    @ViewBuilder
    private func spotlight(_ agent: AgentInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text("默认代理")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.success)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.success.opacity(0.12)))
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.success)
            }

            HStack(alignment: .center, spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .fill(AppColors.success.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Text(agent.emoji.isEmpty ? "🤖" : agent.emoji)
                        .font(.system(size: 36))
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(agent.name)
                        .font(AppTypography.cardTitle)
                    Text(agent.id)
                        .font(AppTypography.captionMono)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                    if let model = agent.model {
                        ModelPill(model: model)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }

            Text("所有未指定代理的聊天请求会路由到这里。")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .strokeBorder(AppColors.success.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Grid

    @ViewBuilder
    private var agentsGrid: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(AppColors.metricTertiary)
                Text("全部代理")
                    .font(AppTypography.captionBold)
                Spacer()
                Text("\(adminVM.agents.count) 个")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(adminVM.agents) { agent in
                    agentCard(agent)
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
    private func agentCard(_ agent: AgentInfo) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                ZStack {
                    Circle()
                        .fill(tint(for: agent).opacity(0.14))
                        .frame(width: 40, height: 40)
                    Text(agent.emoji.isEmpty ? "🤖" : agent.emoji)
                        .font(.system(size: 22))
                }
                Spacer()
                if agent.isDefault {
                    Image(systemName: "star.fill")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.success)
                }
            }

            Text(agent.name)
                .font(AppTypography.captionBold)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(agent.id)
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
                .lineLimit(1)
                .truncationMode(.middle)

            if let model = agent.model {
                ModelPill(model: model)
            } else {
                Text("未指定模型")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.neutral.opacity(0.08)))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.tintedBackground(tint(for: agent), opacity: 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(AppColors.tintedBackground(tint(for: agent), opacity: 0.2), lineWidth: 1)
        )
    }

    private func tint(for agent: AgentInfo) -> Color {
        if agent.isDefault { return AppColors.success }
        // Pseudo-random tint based on id hash, but stable across renders
        let palette: [Color] = [
            AppColors.metricPrimary,
            AppColors.metricTertiary,
            AppColors.metricHighlight,
            AppColors.metricWarm,
            AppColors.info
        ]
        let hash = abs(agent.id.hashValue)
        return palette[hash % palette.count]
    }
}
