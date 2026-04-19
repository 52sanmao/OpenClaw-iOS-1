import SwiftUI

/// 推理控制台 — 对齐 Web UI 的「推理」：
///   - 顶部 hero 显示当前激活 provider + 模型
///   - 内置 / 自定义 provider 分区
///   - 每行有 Use / Configure / Edit / Delete 胶囊按钮（视 kind 显示）
///   - 工具栏「+」：新增自定义 provider
///   - 点击模型清单条目即把它设为默认模型（走 /api/settings/selected_model）
struct InferenceConsoleView: View {
    let adminVM: AdminViewModel

    @State private var probingProviderId: String?
    @State private var listingModelsProviderId: String?
    @State private var probeResult: ProbeResult?
    @State private var modelListResult: ListModelsResult?
    @State private var formMode: LLMProviderFormSheet.Mode?
    @State private var actionError: String?
    @State private var pendingDelete: PendingDelete?
    @State private var settingActiveId: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                activeBackendHero
                customProvidersSection
                builtinProvidersSection
                if adminVM.providers.isEmpty && !adminVM.isLoading {
                    ContentUnavailableView(
                        "暂无推理配置",
                        systemImage: "cpu",
                        description: Text("下拉刷新或检查网关 /api/llm/providers 接口。")
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
                DetailTitleView(title: "推理") {
                    Text(subtitle)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    formMode = .addCustom
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("新增 Provider")
            }
        }
        .refreshable {
            await adminVM.load()
            Haptics.shared.refreshComplete()
        }
        .task {
            if adminVM.providers.isEmpty && !adminVM.isLoading { await adminVM.load() }
        }
        .alert("连接测试", isPresented: Binding(
            get: { probeResult != nil },
            set: { if !$0 { probeResult = nil } }
        )) {
            Button("好的", role: .cancel) { probeResult = nil }
        } message: {
            if let r = probeResult {
                Text(r.provider.name + "：" + r.response.message)
            }
        }
        .sheet(item: $modelListResult) { result in
            ModelListSheet(
                provider: result.provider,
                models: result.models,
                currentModel: adminVM.selectedModel,
                canSelect: result.provider.id == adminVM.selectedBackendId
            ) { model in
                Task { await selectModel(model) }
            }
        }
        .sheet(item: $formMode) { mode in
            LLMProviderFormSheet(mode: mode, adminVM: adminVM) {}
        }
        .alert("操作失败", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("好的", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .confirmationDialog(
            "删除 Provider",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let p = pendingDelete {
                Button("删除 \(p.name)", role: .destructive) {
                    Task { await delete(p.id) }
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            }
        } message: {
            Text("删除后将从 llm_custom_providers 设置里移除，不可撤销。")
        }
    }

    private var subtitle: String {
        let activeId = adminVM.selectedBackendId ?? "default"
        let activeName = adminVM.providers.first(where: { $0.id == activeId })?.name
            ?? adminVM.customProviders.first(where: { $0.id == activeId })?.name
            ?? "未选择"
        let m = adminVM.selectedModel ?? "auto"
        return "\(activeName) · \(m)"
    }

    // MARK: - Active hero

    @ViewBuilder
    private var activeBackendHero: some View {
        let activeId = adminVM.selectedBackendId
        let provider = adminVM.providers.first(where: { $0.id == activeId })
            ?? adminVM.customProviders.first(where: { $0.id == activeId })
            ?? adminVM.providers.first(where: { $0.hasApiKey == true })

        if let provider {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Text("当前推理后端")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.metricPrimary)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.metricPrimary.opacity(0.12)))
                    Spacer()
                    if provider.builtin == true {
                        Button {
                            formMode = .configureBuiltin(provider)
                        } label: {
                            Label("配置", systemImage: "slider.horizontal.3")
                                .font(AppTypography.nano)
                                .fontWeight(.semibold)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(AppColors.metricPrimary.opacity(0.12)))
                                .foregroundStyle(AppColors.metricPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(alignment: .center, spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(AppColors.metricPrimary.opacity(0.12))
                            .frame(width: 64, height: 64)
                        ProviderIcon(provider: provider.id, size: 34)
                    }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(provider.name)
                            .font(AppTypography.cardTitle)
                        Text(adminVM.selectedModel ?? provider.envModel ?? provider.defaultModel ?? "auto")
                            .font(AppTypography.captionMono)
                            .foregroundStyle(AppColors.neutral)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: Spacing.xs) {
                    metaChip(label: "Adapter", value: adapterLabel(provider.adapter))
                    metaChip(label: provider.builtin == true ? "内置" : "自定义",
                             value: apiKeyStatus(for: provider))
                }
                .fixedSize(horizontal: false, vertical: true)
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
    }

    private func apiKeyStatus(for provider: LLMProviderDTO) -> String {
        if let override = adminVM.builtinOverride(for: provider.id),
           override.apiKey == LLMKeySentinel.unchanged || (override.apiKey?.isEmpty == false) {
            return "override 已存"
        }
        return provider.hasApiKey == true ? "已配置" : "待配置"
    }

    // MARK: - Sections

    @ViewBuilder
    private var customProvidersSection: some View {
        if !adminVM.customProviders.isEmpty {
            providerSection(
                title: "自定义 Provider",
                icon: "sparkles",
                tint: AppColors.metricTertiary,
                providers: adminVM.customProviders
            )
        }
    }

    @ViewBuilder
    private var builtinProvidersSection: some View {
        if !adminVM.providers.isEmpty {
            providerSection(
                title: "内置 Provider",
                icon: "shippingbox.fill",
                tint: AppColors.metricPrimary,
                providers: adminVM.providers
            )
        }
    }

    @ViewBuilder
    private func providerSection(title: String, icon: String, tint: Color, providers: [LLMProviderDTO]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(AppTypography.captionBold)
                Spacer()
                Text("\(providers.count) 个")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
            VStack(spacing: Spacing.sm) {
                ForEach(providers, id: \.id) { p in
                    providerRow(p)
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
    private func providerRow(_ provider: LLMProviderDTO) -> some View {
        let isActive = provider.id == adminVM.selectedBackendId
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill((isActive ? AppColors.success : AppColors.neutral).opacity(0.14))
                        .frame(width: 36, height: 36)
                    ProviderIcon(provider: provider.id, size: 20)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: Spacing.xxs) {
                        Text(provider.name)
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
                        if provider.hasApiKey == true || adminVM.builtinOverride(for: provider.id)?.apiKey != nil {
                            Image(systemName: "key.fill")
                                .font(AppTypography.nano)
                                .foregroundStyle(AppColors.success)
                        }
                    }
                    Text(effectiveModel(for: provider))
                        .font(AppTypography.captionMono)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let base = effectiveBaseUrl(for: provider), !base.isEmpty {
                        Text(base)
                            .font(AppTypography.nano)
                            .foregroundStyle(AppColors.neutral)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
            }

            actionBar(provider: provider, isActive: isActive)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(isActive ? AppColors.success.opacity(0.05) : Color(.systemGroupedBackground))
        )
    }

    @ViewBuilder
    private func actionBar(provider: LLMProviderDTO, isActive: Bool) -> some View {
        FlowChipsLayout(spacing: Spacing.xs) {
            if !isActive {
                actionChip(
                    icon: "bolt.fill",
                    label: settingActiveId == provider.id ? "切换中…" : "启用",
                    tint: AppColors.success,
                    isLoading: settingActiveId == provider.id
                ) {
                    Task { await setActive(provider) }
                }
            }

            if provider.builtin == true && provider.id != "bedrock" {
                actionChip(
                    icon: "slider.horizontal.3",
                    label: "配置",
                    tint: AppColors.primaryAction
                ) {
                    formMode = .configureBuiltin(provider)
                }
            }

            if provider.builtin == false {
                actionChip(
                    icon: "pencil",
                    label: "编辑",
                    tint: AppColors.info
                ) {
                    if let dto = adminVM.customProviderDTOs.first(where: { $0.id == provider.id }) {
                        formMode = .editCustom(dto)
                    }
                }
            }

            actionChip(
                icon: "bolt.horizontal.circle",
                label: probingProviderId == provider.id ? "测试中…" : "测试",
                tint: AppColors.primaryAction,
                isLoading: probingProviderId == provider.id
            ) {
                Task { await runTest(provider) }
            }

            if provider.canListModels == true {
                actionChip(
                    icon: "list.bullet.rectangle.portrait",
                    label: listingModelsProviderId == provider.id ? "拉取中…" : "模型",
                    tint: AppColors.metricTertiary,
                    isLoading: listingModelsProviderId == provider.id
                ) {
                    Task { await runListModels(provider) }
                }
            }

            if provider.builtin == false && !isActive {
                actionChip(
                    icon: "trash",
                    label: "删除",
                    tint: AppColors.danger,
                    role: .destructive
                ) {
                    pendingDelete = PendingDelete(id: provider.id, name: provider.name)
                }
            }
        }
    }

    @ViewBuilder
    private func actionChip(icon: String, label: String, tint: Color, isLoading: Bool = false, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: Spacing.xxs) {
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: icon)
                        .font(AppTypography.nano)
                }
                Text(label)
                    .font(AppTypography.nano)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    @ViewBuilder
    private func metaChip(label: String, value: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Text(label)
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
            Text(value)
                .font(AppTypography.captionMono)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 4)
        .background(Capsule().fill(AppColors.neutral.opacity(0.08)))
    }

    // MARK: - Helpers

    private func effectiveModel(for provider: LLMProviderDTO) -> String {
        if provider.id == adminVM.selectedBackendId {
            return adminVM.selectedModel ?? provider.envModel ?? provider.defaultModel ?? "-"
        }
        if let override = adminVM.builtinOverride(for: provider.id), let m = override.model, !m.isEmpty {
            return m
        }
        return provider.envModel ?? provider.defaultModel ?? "-"
    }

    private func effectiveBaseUrl(for provider: LLMProviderDTO) -> String? {
        if let override = adminVM.builtinOverride(for: provider.id), let base = override.baseUrl, !base.isEmpty {
            return base
        }
        return provider.envBaseUrl ?? provider.baseUrl
    }

    private func adapterLabel(_ adapter: String?) -> String {
        switch adapter ?? "" {
        case "open_ai_completions": return "OpenAI Compatible"
        case "anthropic":           return "Anthropic"
        case "ollama":              return "Ollama"
        case "bedrock":             return "AWS Bedrock"
        case "nearai":              return "NEAR AI"
        default:                    return adapter ?? "-"
        }
    }

    // MARK: - Actions

    private func setActive(_ provider: LLMProviderDTO) async {
        settingActiveId = provider.id
        defer { settingActiveId = nil }
        do {
            try await adminVM.setActiveLLMBackend(id: provider.id)
            if let m = provider.defaultModel ?? provider.envModel {
                try? await adminVM.setSelectedModel(m)
            }
            await adminVM.load()
            Haptics.shared.success()
        } catch {
            actionError = error.localizedDescription
            Haptics.shared.error()
        }
    }

    private func delete(_ id: String) async {
        pendingDelete = nil
        do {
            try await adminVM.removeCustomProvider(id: id)
            Haptics.shared.success()
        } catch {
            actionError = error.localizedDescription
            Haptics.shared.error()
        }
    }

    private func selectModel(_ model: String) async {
        do {
            try await adminVM.setSelectedModel(model)
            await adminVM.load()
            modelListResult = nil
            Haptics.shared.success()
        } catch {
            actionError = error.localizedDescription
            Haptics.shared.error()
        }
    }

    private func runTest(_ provider: LLMProviderDTO) async {
        probingProviderId = provider.id
        let response = await adminVM.testConnection(for: provider)
        probingProviderId = nil
        probeResult = ProbeResult(provider: provider, response: response)
        if response.ok { Haptics.shared.success() } else { Haptics.shared.error() }
    }

    private func runListModels(_ provider: LLMProviderDTO) async {
        listingModelsProviderId = provider.id
        let response = await adminVM.listModels(for: provider)
        listingModelsProviderId = nil
        modelListResult = ListModelsResult(provider: provider, models: response.models)
        Haptics.shared.refreshComplete()
    }

    private struct ProbeResult {
        let provider: LLMProviderDTO
        let response: LLMTestConnectionResponse
    }

    private struct ListModelsResult: Identifiable {
        var id: String { provider.id }
        let provider: LLMProviderDTO
        let models: [String]
    }

    private struct PendingDelete: Identifiable {
        let id: String
        let name: String
    }
}

// MARK: - Model list sheet

private struct ModelListSheet: View {
    let provider: LLMProviderDTO
    let models: [String]
    let currentModel: String?
    let canSelect: Bool
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if models.isEmpty {
                        ContentUnavailableView(
                            "没有返回模型",
                            systemImage: "tray",
                            description: Text("该 provider 未返回模型清单。")
                        )
                    } else {
                        ForEach(models, id: \.self) { model in
                            Button {
                                if canSelect { onSelect(model) }
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: model == currentModel ? "checkmark.circle.fill" : "cpu")
                                        .foregroundStyle(model == currentModel ? AppColors.success : AppColors.metricPrimary)
                                    Text(model)
                                        .font(AppTypography.captionMono)
                                        .textSelection(.enabled)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if canSelect && model != currentModel {
                                        Text("设为默认")
                                            .font(AppTypography.nano)
                                            .foregroundStyle(AppColors.primaryAction)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("\(provider.name) · \(models.count) 个模型")
                } footer: {
                    Text(canSelect
                        ? "点击模型可将其设为当前默认（调用 /api/settings/selected_model）。"
                        : "这个 provider 当前未启用。先在推理页点「启用」，再回来切换模型。")
                    .font(AppTypography.nano)
                }
            }
            .navigationTitle("模型清单")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
