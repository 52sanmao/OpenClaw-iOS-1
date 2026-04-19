import SwiftUI

/// 用户管理控制台 — 当前账号 hero + 账号列表 + 快速切换与删除。
/// 与底层 SettingsView 的诊断页面分离，专注账号/网关身份管理。
struct UsersConsoleView: View {
    @Bindable var accountStore: AccountStore
    let client: GatewayClientProtocol

    @State private var showAddAccount = false
    @State private var accountToDelete: GatewayAccount?
    @State private var isTesting = false
    @State private var testResult: TestOutcome?

    init(accountStore: AccountStore, client: GatewayClientProtocol) {
        self.accountStore = accountStore
        self.client = client
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let active = accountStore.activeAccount {
                    activeAccountCard(active)
                } else {
                    noAccountCard
                }

                if accountStore.accounts.count > 1 {
                    accountListCard
                }

                addAccountButton
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "用户管理") {
                    Text(subtitle)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView(accountStore: accountStore)
        }
        .alert("删除账号？", isPresented: Binding(
            get: { accountToDelete != nil },
            set: { if !$0 { accountToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let account = accountToDelete {
                    accountStore.delete(account.id)
                }
            }
            Button("取消", role: .cancel) { accountToDelete = nil }
        } message: {
            if let account = accountToDelete {
                Text("要移除「\(account.name)」吗？对应 Token 也会从 Keychain 中删除。")
            }
        }
    }

    private var subtitle: String {
        "\(accountStore.accounts.count) 个账号 · 当前 \(accountStore.activeAccount?.name ?? "未配置")"
    }

    // MARK: - Active hero

    @ViewBuilder
    private func activeAccountCard(_ account: GatewayAccount) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text("当前账号")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.success)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.success.opacity(0.12)))
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.success)
            }

            HStack(alignment: .center, spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.success.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Text(initials(for: account.name))
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.success)
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(account.name)
                        .font(AppTypography.cardTitle)
                        .lineLimit(1)
                    Text(account.displayURL)
                        .font(AppTypography.captionMono)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }

            Divider()

            VStack(spacing: Spacing.xs) {
                metaRow(icon: "person.circle", label: "Agent", value: account.agentId)
                metaRow(icon: "folder", label: "工作区", value: account.workspaceRoot)
            }

            Button {
                runConnectionTest()
            } label: {
                HStack(spacing: Spacing.xs) {
                    if isTesting {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "network")
                    }
                    Text(isTesting ? "正在测试…" : "测试连接")
                        .fontWeight(.semibold)
                    Spacer()
                    if let result = testResult {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.isSuccess ? AppColors.success : AppColors.danger)
                    }
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.primaryAction)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(AppColors.primaryAction.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .disabled(isTesting)

            if let result = testResult {
                Text(result.message)
                    .font(AppTypography.micro)
                    .foregroundStyle(result.isSuccess ? AppColors.success : AppColors.danger)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                .strokeBorder(AppColors.success.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func metaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
                .frame(width: 16)
            Text(label)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
            Spacer()
            Text(value)
                .font(AppTypography.captionMono)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - No account

    @ViewBuilder
    private var noAccountCard: some View {
        VStack(alignment: .center, spacing: Spacing.sm) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(AppColors.warning)
            Text("尚未配置网关账号")
                .font(AppTypography.cardTitle)
            Text("添加一个 IronClaw 网关账号来开始使用聊天、记忆与定时任务。")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    // MARK: - Account list

    @ViewBuilder
    private var accountListCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(AppColors.info)
                Text("全部账号")
                    .font(AppTypography.captionBold)
                Spacer()
                Text("\(accountStore.accounts.count) 个")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(accountStore.accounts) { account in
                    accountRow(account)
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
    private func accountRow(_ account: GatewayAccount) -> some View {
        let isActive = account.id == accountStore.activeAccountId
        Button {
            if !isActive {
                accountStore.setActive(account.id)
                testResult = nil
                Haptics.shared.success()
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill((isActive ? AppColors.success : AppColors.neutral).opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(initials(for: account.name))
                        .font(AppTypography.captionBold)
                        .foregroundStyle(isActive ? AppColors.success : AppColors.neutral)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: Spacing.xxs) {
                        Text(account.name)
                            .font(AppTypography.body)
                            .foregroundStyle(.primary)
                        if isActive {
                            Text("使用中")
                                .font(AppTypography.nano)
                                .padding(.horizontal, Spacing.xxs)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(AppColors.success.opacity(0.14)))
                                .foregroundStyle(AppColors.success)
                        }
                    }
                    Text(account.displayURL)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if !isActive {
                    Image(systemName: "arrow.right.circle")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primaryAction)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, Spacing.xxs)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                accountToDelete = account
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - Add button

    @ViewBuilder
    private var addAccountButton: some View {
        Button {
            showAddAccount = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                Text("添加网关账号")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppTypography.nano)
            }
            .font(AppTypography.body)
            .foregroundStyle(AppColors.primaryAction)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(AppColors.primaryAction.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let firstScalar = trimmed.unicodeScalars.first!
        if firstScalar.value >= 0x4E00 && firstScalar.value <= 0x9FFF {
            return String(trimmed.prefix(1))
        }
        let parts = trimmed.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    private func runConnectionTest() {
        isTesting = true
        testResult = nil
        Task {
            do {
                let result = try await client.validateGatewayConnection(testMessage: "Hello from OpenClaw 用户管理")
                testResult = TestOutcome(isSuccess: true, message: result.summary)
                Haptics.shared.success()
            } catch {
                testResult = TestOutcome(isSuccess: false, message: error.localizedDescription)
                Haptics.shared.error()
            }
            isTesting = false
        }
    }
}

private struct TestOutcome {
    let isSuccess: Bool
    let message: String
}
