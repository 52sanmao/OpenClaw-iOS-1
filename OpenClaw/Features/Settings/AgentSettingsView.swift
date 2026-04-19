import SwiftUI

/// 代理配置视图 — 对齐 Web 端的代理管理功能
/// 支持代理选择、系统提示词编辑、行为配置
struct AgentSettingsView: View {
    let adminVM: AdminViewModel

    @State private var selectedAgentId: String?
    @State private var editingPrompt = false
    @State private var draftPrompt = ""
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                currentAgentCard

                if !adminVM.agents.isEmpty {
                    agentListSection
                }

                if let agent = adminVM.agent {
                    behaviorSection(agent)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "代理配置") {
                    Text(adminVM.agent?.displayName ?? "未选择")
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
        .alert("保存失败", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好的", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Current Agent Card

    @ViewBuilder
    private var currentAgentCard: some View {
        if let agent = adminVM.agent {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Text("当前代理")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.success)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.success.opacity(0.12)))
                    Spacer()
                }

                HStack(alignment: .center, spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(AppColors.success.opacity(0.14))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(AppColors.success)
                    }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(agent.displayName)
                            .font(AppTypography.cardTitle)
                        Text("角色: \(agent.role)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.neutral)
                        Text("模型: \(agent.model)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.neutral)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(AppColors.success.opacity(0.18), lineWidth: 1)
            )
        }
    }

    // MARK: - Agent List

    @ViewBuilder
    private var agentListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppColors.metricTertiary)
                Text("可用代理")
                    .font(AppTypography.captionBold)
                Spacer()
                Text("\(adminVM.agents.count) 个")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(adminVM.agents) { agent in
                    agentRow(agent)
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
    private func agentRow(_ agent: AgentInfo) -> some View {
        let isActive = agent.id == adminVM.agent?.id

        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill((isActive ? AppColors.success : AppColors.neutral).opacity(0.14))
                    .frame(width: 36, height: 36)
                Text(agent.emoji)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: Spacing.xxs) {
                    Text(agent.name)
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if isActive {
                        Text("使用中")
                            .font(AppTypography.nano)
                            .padding(.horizontal, Spacing.xxs)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(AppColors.success.opacity(0.15)))
                            .foregroundStyle(AppColors.success)
                    }
                    if agent.isDefault {
                        Text("默认")
                            .font(AppTypography.nano)
                            .padding(.horizontal, Spacing.xxs)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(AppColors.info.opacity(0.15)))
                            .foregroundStyle(AppColors.info)
                    }
                }
                if let model = agent.model {
                    Text(model)
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(isActive ? AppColors.success.opacity(0.05) : Color(.systemGroupedBackground))
        )
    }

    // MARK: - Behavior

    @ViewBuilder
    private func behaviorSection(_ agent: AgentProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(AppColors.metricPrimary)
                Text("行为配置")
                    .font(AppTypography.captionBold)
                Spacer()
            }

            VStack(spacing: Spacing.xs) {
                behaviorRow(icon: "brain.head.profile", label: "使用规划", value: agent.usePlanning ? "启用" : "禁用", enabled: agent.usePlanning)
                behaviorRow(icon: "checkmark.circle.fill", label: "自动批准工具", value: agent.autoApproveTools ? "启用" : "禁用", enabled: agent.autoApproveTools)
                behaviorRow(icon: "wrench.and.screwdriver", label: "允许本地工具", value: agent.allowLocalTools ? "启用" : "禁用", enabled: agent.allowLocalTools)

                if !agent.activatedChannels.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(AppColors.success)
                                .frame(width: 24)
                            Text("激活的频道")
                                .font(AppTypography.body)
                            Spacer()
                        }
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .fill(Color(.systemGroupedBackground))
                        )

                        ForEach(agent.activatedChannels, id: \.self) { channel in
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(AppColors.success)
                                Text(channel)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.neutral)
                                Spacer()
                            }
                            .padding(.leading, Spacing.md)
                        }
                    }
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
    private func behaviorRow(icon: String, label: String, value: String, enabled: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(enabled ? AppColors.success : AppColors.neutral)
                .frame(width: 24)
            Text(label)
                .font(AppTypography.body)
            Spacer()
            Text(value)
                .font(AppTypography.caption)
                .foregroundStyle(enabled ? AppColors.success : AppColors.neutral)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color(.systemGroupedBackground))
        )
    }
}
