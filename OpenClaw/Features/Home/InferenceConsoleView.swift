import SwiftUI

/// 模型控制台 — hero 卡 + 回退链 + 别名网格，专为“推理配置”场景设计。
struct InferenceConsoleView: View {
    let adminVM: AdminViewModel

    @State private var showAllAliases = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let config = adminVM.modelsConfig {
                    heroCard(config)
                    fallbackChain(config)
                    if let imageModel = config.imageModel {
                        imageModelCard(imageModel)
                    }
                    aliasesGrid(config)
                } else if adminVM.isLoading {
                    CardLoadingView(minHeight: 180)
                } else if let error = adminVM.error {
                    CardErrorView(error: error, minHeight: 140)
                } else {
                    ContentUnavailableView(
                        "暂无模型配置",
                        systemImage: "cpu",
                        description: Text("刷新或检查网关的 models-status 扩展接口。")
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
                DetailTitleView(title: "模型") {
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
            if adminVM.modelsConfig == nil && !adminVM.isLoading {
                await adminVM.load()
            }
        }
    }

    private var subtitle: String {
        if let display = adminVM.modelsConfig?.defaultModelDisplay {
            let fallbackCount = adminVM.modelsConfig?.fallbacks.count ?? 0
            let aliasCount = adminVM.modelsConfig?.aliases.count ?? 0
            return "\(display) · \(fallbackCount) 个回退 · \(aliasCount) 个别名"
        }
        return "查看当前推理配置"
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroCard(_ config: ModelsConfig) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text("主力模型")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.metricPrimary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.metricPrimary.opacity(0.12)))
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.metricPrimary)
            }

            HStack(alignment: .center, spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.metricPrimary.opacity(0.12))
                        .frame(width: 64, height: 64)
                    ProviderIcon(model: config.defaultModel, size: 34)
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(Formatters.modelShortName(config.defaultModel))
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(config.defaultModel)
                        .font(AppTypography.captionMono)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }

            Text("默认用于所有聊天与代理请求，除非代理单独指定。")
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
                .strokeBorder(AppColors.metricPrimary.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Fallback chain

    @ViewBuilder
    private func fallbackChain(_ config: ModelsConfig) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(AppColors.metricSecondary)
                Text("回退链")
                    .font(AppTypography.captionBold)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(config.fallbacks.count) 个")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            if config.fallbacks.isEmpty {
                Text("未配置回退 — 主模型失败时不会自动降级。")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            } else {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(Array(config.fallbacks.enumerated()), id: \.offset) { index, model in
                        fallbackRow(index: index, model: model, isLast: index == config.fallbacks.count - 1)
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
    private func fallbackRow(index: Int, model: String, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.metricSecondary.opacity(0.12))
                    .frame(width: 26, height: 26)
                Text("\(index + 1)")
                    .font(AppTypography.captionBold)
                    .foregroundStyle(AppColors.metricSecondary)
            }
            ProviderIcon(model: model, size: 16)
            Text(Formatters.modelShortName(model))
                .font(AppTypography.body)
                .lineLimit(1)
            Spacer()
            if !isLast {
                Image(systemName: "arrow.down")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral.opacity(0.5))
            } else {
                Text("终端")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
        }
    }

    // MARK: - Image model

    @ViewBuilder
    private func imageModelCard(_ imageModel: String) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.metricTertiary.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "photo.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.metricTertiary)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("图像模型")
                    .font(AppTypography.captionBold)
                Text(Formatters.modelShortName(imageModel))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(1)
            }
            Spacer()
            ProviderIcon(model: imageModel, size: 20)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Aliases

    @ViewBuilder
    private func aliasesGrid(_ config: ModelsConfig) -> some View {
        if config.aliases.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(AppColors.metricWarm)
                    Text("模型别名")
                        .font(AppTypography.captionBold)
                    Spacer()
                    Text("\(config.aliases.count) 个")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }

                let visible = showAllAliases ? config.aliases : Array(config.aliases.prefix(4))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.xs), GridItem(.flexible(), spacing: Spacing.xs)], spacing: Spacing.xs) {
                    ForEach(visible, id: \.name) { alias in
                        aliasTile(name: alias.name, model: alias.model)
                    }
                }

                if config.aliases.count > 4 {
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { showAllAliases.toggle() }
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Text(showAllAliases ? "收起" : "展开全部 \(config.aliases.count) 个")
                                .font(AppTypography.caption)
                            Image(systemName: "chevron.down")
                                .font(AppTypography.nano)
                                .rotationEffect(.degrees(showAllAliases ? 180 : 0))
                        }
                        .foregroundStyle(AppColors.primaryAction)
                        .frame(maxWidth: .infinity)
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
    private func aliasTile(name: String, model: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(name)
                .font(AppTypography.captionBold)
                .foregroundStyle(AppColors.primaryAction)
                .lineLimit(1)
            HStack(spacing: Spacing.xxs) {
                ProviderIcon(model: model, size: 12)
                Text(Formatters.modelShortName(model))
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.primaryAction.opacity(0.06))
        )
    }
}
