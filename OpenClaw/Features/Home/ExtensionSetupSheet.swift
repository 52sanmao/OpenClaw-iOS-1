import SwiftUI

/// 频道/扩展凭据配置表单 — 对齐 Web UI 的 `showConfigureModal()`。
/// 拿 `GET /api/extensions/{name}/setup` 回来的 `secrets` 字段，展示表单，
/// 保存走 `POST /api/extensions/{name}/setup`。
struct ExtensionSetupSheet: View {
    let extensionName: String
    let displayName: String
    let adminVM: AdminViewModel
    let onComplete: () -> Void

    @State private var loading = true
    @State private var saving = false
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var secrets: [ExtensionSecretFieldDTO] = []
    @State private var onboarding: ExtensionOnboardingDTO?
    @State private var values: [String: String] = [:]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("加载配置字段…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    ContentUnavailableView(
                        "无法加载",
                        systemImage: "exclamationmark.triangle.fill",
                        description: Text(err)
                    )
                } else {
                    formBody
                }
            }
            .navigationTitle("配置 \(displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .task { await load() }
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

    @ViewBuilder
    private var formBody: some View {
        Form {
            if let o = onboarding {
                Section {
                    if let title = o.credentialTitle, !title.isEmpty {
                        Text(title).font(AppTypography.captionBold)
                    }
                    if let desc = o.credentialInstructions, !desc.isEmpty {
                        Text(desc)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.neutral)
                    }
                    if let url = o.setupUrl, let linkUrl = URL(string: url) {
                        Link(destination: linkUrl) {
                            Label("获取凭据", systemImage: "arrow.up.right.square")
                                .font(AppTypography.caption)
                        }
                    }
                }
            }

            Section {
                if secrets.isEmpty {
                    Text("这个扩展不需要额外凭据。")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.neutral)
                }
                ForEach(secrets, id: \.name) { field in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(field.label ?? field.name)
                            .font(AppTypography.caption)
                            .fontWeight(.medium)
                        if (field.type ?? "").lowercased() == "password" {
                            SecureField(field.placeholder ?? field.name,
                                        text: Binding(
                                            get: { values[field.name] ?? "" },
                                            set: { values[field.name] = $0 }
                                        ))
                            .textContentType(.password)
                            .autocorrectionDisabled()
                        } else {
                            TextField(field.placeholder ?? field.name,
                                      text: Binding(
                                        get: { values[field.name] ?? "" },
                                        set: { values[field.name] = $0 }
                                      ))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        }
                        if let desc = field.description, !desc.isEmpty {
                            Text(desc)
                                .font(AppTypography.nano)
                                .foregroundStyle(AppColors.neutral)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("凭据")
            }

            if let next = onboarding?.credentialNextStep, !next.isEmpty {
                Section {
                    Text(next)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.neutral)
                } header: {
                    Text("下一步")
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if saving { ProgressView().scaleEffect(0.75) }
                        Text(saving ? "保存中…" : "保存")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(saving)
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let resp = try await adminVM.loadExtensionSetup(name: extensionName)
            secrets = resp.secrets ?? []
            onboarding = resp.onboarding
            for s in secrets where values[s.name] == nil {
                values[s.name] = ""
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func submit() async {
        saving = true
        defer { saving = false }
        let nonEmpty = values.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        do {
            _ = try await adminVM.submitExtensionSetup(name: extensionName, secrets: nonEmpty)
            Haptics.shared.success()
            onComplete()
            dismiss()
        } catch {
            saveError = error.localizedDescription
            Haptics.shared.error()
        }
    }
}
