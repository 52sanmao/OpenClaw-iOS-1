import SwiftUI

/// Provider 配置表单 —— 对齐 Web UI 的 `#provider-dialog`。
/// 覆盖三种模式：
///   - `.addCustom`：新增 custom provider
///   - `.editCustom(LLMCustomProviderDTO)`：修改已有 custom
///   - `.configureBuiltin(LLMProviderDTO)`：为内置 provider 填 api_key / model / base_url override
struct LLMProviderFormSheet: View {
    enum Mode: Identifiable {
        case addCustom
        case editCustom(LLMCustomProviderDTO)
        case configureBuiltin(LLMProviderDTO)

        var id: String {
            switch self {
            case .addCustom: return "add"
            case .editCustom(let p): return "edit-\(p.id)"
            case .configureBuiltin(let p): return "configure-\(p.id)"
            }
        }
    }

    let mode: Mode
    let adminVM: AdminViewModel
    let onComplete: () -> Void

    @State private var name: String = ""
    @State private var providerId: String = ""
    @State private var adapter: String = "open_ai_completions"
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var fetchedModels: [String] = []
    @State private var fetching = false
    @State private var testing = false
    @State private var testResult: (ok: Bool, message: String)?
    @State private var saving = false
    @State private var saveError: String?
    @State private var hadKey = false
    @Environment(\.dismiss) private var dismiss

    private let adapters: [(id: String, label: String)] = [
        ("open_ai_completions", "OpenAI Compatible"),
        ("anthropic", "Anthropic"),
        ("ollama", "Ollama"),
        ("bedrock", "AWS Bedrock"),
        ("nearai", "NEAR AI")
    ]

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                connectionSection
                modelSection
                testSection
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Text("保存").fontWeight(.semibold)
                        }
                    }
                    .disabled(saving || !canSave)
                }
            }
            .task { populateInitial() }
            .alert("保存失败", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("好的", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var title: String {
        switch mode {
        case .addCustom:            return "新增 Provider"
        case .editCustom:           return "编辑 Provider"
        case .configureBuiltin(let p): return "配置 · \(p.name)"
        }
    }

    private var canSave: Bool {
        switch mode {
        case .addCustom:
            let idOK = providerId.range(of: "^[a-z0-9_-]+$", options: .regularExpression) != nil
            return !name.isEmpty && idOK
        case .editCustom:    return !name.isEmpty
        case .configureBuiltin: return true
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var identitySection: some View {
        if case .addCustom = mode {
            Section("基础") {
                TextField("名称（显示用）", text: $name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: name) { _, newValue in
                        if providerId.isEmpty || wasAutoIdFor(previousName: oldName) {
                            providerId = newValue.lowercased()
                                .replacingOccurrences(of: "[^a-z0-9_]+", with: "-", options: .regularExpression)
                                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                            oldName = newValue
                        }
                    }
                TextField("ID（小写字母/数字/-）", text: $providerId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("适配器", selection: $adapter) {
                    ForEach(adapters, id: \.id) { a in
                        Text(a.label).tag(a.id)
                    }
                }
            }
        } else if case .editCustom(let p) = mode {
            Section("基础") {
                TextField("名称", text: $name)
                    .textInputAutocapitalization(.words)
                HStack {
                    Text("ID").foregroundStyle(AppColors.neutral).font(AppTypography.caption)
                    Spacer()
                    Text(p.id).font(AppTypography.captionMono).foregroundStyle(AppColors.neutral)
                }
                Picker("适配器", selection: $adapter) {
                    ForEach(adapters, id: \.id) { a in
                        Text(a.label).tag(a.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var connectionSection: some View {
        Section {
            TextField("Base URL", text: $baseURL)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()

            SecureField(hadKey ? "••••••••（已保存）" : "API Key", text: $apiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
        } header: {
            Text("连接")
        } footer: {
            Text(hadKey ? "留空 = 保留已存密钥；输入新值会覆盖。" : "")
                .font(AppTypography.nano)
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        Section("默认模型") {
            TextField("模型 ID", text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if canFetchModels {
                Button {
                    Task { await fetchModels() }
                } label: {
                    HStack {
                        if fetching {
                            ProgressView().scaleEffect(0.7)
                            Text("拉取中…")
                        } else {
                            Label("从后端拉取模型清单", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .font(AppTypography.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(fetching)
            }

            if !fetchedModels.isEmpty {
                Picker("选择模型", selection: $model) {
                    ForEach(fetchedModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private var testSection: some View {
        Section {
            Button {
                Task { await testConnection() }
            } label: {
                HStack {
                    if testing { ProgressView().scaleEffect(0.7) }
                    Text(testing ? "测试中…" : "测试连接")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(testing || model.isEmpty)

            if let r = testResult {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: r.ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(r.ok ? AppColors.success : AppColors.danger)
                    Text(r.message)
                        .font(AppTypography.caption)
                        .foregroundStyle(r.ok ? AppColors.success : AppColors.danger)
                }
            }
        } footer: {
            Text("调用 POST /api/llm/test_connection，用已填写的配置作参数。")
                .font(AppTypography.nano)
        }
    }

    // MARK: - Logic

    @State private var oldName: String = ""

    private var canFetchModels: Bool {
        switch mode {
        case .addCustom, .editCustom:
            return !adapter.isEmpty
        case .configureBuiltin(let p):
            return p.canListModels == true
        }
    }

    private func wasAutoIdFor(previousName: String) -> Bool {
        let expected = previousName.lowercased()
            .replacingOccurrences(of: "[^a-z0-9_]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return providerId == expected
    }

    private func populateInitial() {
        switch mode {
        case .addCustom:
            name = ""
            providerId = ""
            adapter = "open_ai_completions"
            baseURL = ""
            apiKey = ""
            model = ""
            hadKey = false
        case .editCustom(let p):
            name = p.name
            providerId = p.id
            adapter = p.adapter
            baseURL = p.baseUrl ?? ""
            model = p.defaultModel ?? ""
            hadKey = (p.apiKey != nil && p.apiKey != "")
            apiKey = ""
        case .configureBuiltin(let p):
            let override = adminVM.builtinOverride(for: p.id)
            name = p.name
            providerId = p.id
            adapter = p.adapter ?? "open_ai_completions"
            baseURL = override?.baseUrl ?? p.envBaseUrl ?? p.baseUrl ?? ""
            model = override?.model ?? p.envModel ?? p.defaultModel ?? ""
            hadKey = override?.apiKey == LLMKeySentinel.unchanged || p.hasApiKey == true
            apiKey = ""
        }
    }

    private func testConnection() async {
        testing = true
        defer { testing = false }
        let providerType: String = {
            if case .configureBuiltin = mode { return "builtin" }
            return "custom"
        }()
        let body = LLMTestConnectionRequest(
            adapter: adapter,
            baseUrl: baseURL,
            model: model,
            providerId: providerId,
            providerType: providerType
        )
        do {
            let resp: LLMTestConnectionResponse = try await adminVM.testConnectionRaw(body)
            testResult = (resp.ok, resp.message)
            if resp.ok { Haptics.shared.success() } else { Haptics.shared.error() }
        } catch {
            testResult = (false, error.localizedDescription)
            Haptics.shared.error()
        }
    }

    private func fetchModels() async {
        fetching = true
        defer { fetching = false }
        let providerType: String = {
            if case .configureBuiltin = mode { return "builtin" }
            return "custom"
        }()
        let body = LLMListModelsRequest(
            adapter: adapter,
            baseUrl: baseURL,
            providerId: providerId,
            providerType: providerType
        )
        do {
            let resp: LLMListModelsResponse = try await adminVM.listModelsRaw(body)
            if resp.ok {
                fetchedModels = resp.models
                if model.isEmpty, let first = resp.models.first { model = first }
                Haptics.shared.success()
            } else {
                saveError = resp.message
                Haptics.shared.error()
            }
        } catch {
            saveError = error.localizedDescription
            Haptics.shared.error()
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            switch mode {
            case .addCustom:
                let dto = LLMCustomProviderDTO(
                    id: providerId,
                    name: name,
                    adapter: adapter,
                    baseUrl: baseURL.isEmpty ? nil : baseURL,
                    defaultModel: model.isEmpty ? nil : model,
                    apiKey: apiKey.isEmpty ? nil : apiKey,
                    builtin: false
                )
                var list = adminVM.customProviderDTOs
                list.append(dto)
                try await adminVM.saveCustomProviders(list)
            case .editCustom(let existing):
                let effectiveKey: String?
                if !apiKey.isEmpty {
                    effectiveKey = apiKey
                } else if hadKey {
                    effectiveKey = LLMKeySentinel.unchanged
                } else {
                    effectiveKey = nil
                }
                let dto = LLMCustomProviderDTO(
                    id: existing.id,
                    name: name,
                    adapter: adapter,
                    baseUrl: baseURL.isEmpty ? nil : baseURL,
                    defaultModel: model.isEmpty ? nil : model,
                    apiKey: effectiveKey,
                    builtin: false
                )
                var list = adminVM.customProviderDTOs
                if let idx = list.firstIndex(where: { $0.id == existing.id }) {
                    list[idx] = dto
                } else {
                    list.append(dto)
                }
                try await adminVM.saveCustomProviders(list)
            case .configureBuiltin(let p):
                var overrides = adminVM.builtinOverrides
                var override = overrides[p.id] ?? LLMBuiltinOverrideDTO()
                if !apiKey.isEmpty {
                    override.apiKey = apiKey
                } else if hadKey {
                    override.apiKey = LLMKeySentinel.unchanged
                } else {
                    override.apiKey = nil
                }
                override.model = model.isEmpty ? nil : model
                override.baseUrl = baseURL.isEmpty ? nil : baseURL
                overrides[p.id] = override
                try await adminVM.saveBuiltinOverrides(overrides)
                if p.id == adminVM.selectedBackendId, !model.isEmpty {
                    try await adminVM.setSelectedModel(model)
                }
            }
            Haptics.shared.success()
            onComplete()
            dismiss()
        } catch {
            saveError = error.localizedDescription
            Haptics.shared.error()
        }
    }
}
