import SwiftUI
import UIKit

/// 用户详情 — 对齐 Web Admin `/users/:id` 路由：Profile 卡 + 统计卡 +
/// 角色切换 + 30 天模型用量列表。所有操作走 `AdminViewModel` 的 REST 封装。
struct AdminUserDetailView: View {
    let userId: String
    let adminVM: AdminViewModel

    @State private var user: AdminUserDTO?
    @State private var usage: [AdminUsageEntryDTO] = []
    @State private var loading = true
    @State private var actionError: String?
    @State private var issuedToken: String?
    @State private var pendingAction: PendingAction?
    @State private var draftRole: String = "member"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if loading {
                    ProgressView("加载用户…")
                        .padding(.top, Spacing.xl)
                } else if let u = user {
                    profileCard(u)
                    summaryCard(u)
                    roleSection(u)
                    tokenSection(u)
                    usageCard
                    deleteSection(u)
                } else {
                    ContentUnavailableView("找不到用户", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: user?.displayName ?? "用户") {
                    Text(user?.id ?? userId)
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert("操作失败", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("好的", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .alert("Token 已生成", isPresented: Binding(
            get: { issuedToken != nil },
            set: { if !$0 { issuedToken = nil } }
        )) {
            Button("复制", role: .none) {
                if let t = issuedToken { UIPasteboard.general.string = t }
                issuedToken = nil
            }
            Button("关闭", role: .cancel) { issuedToken = nil }
        } message: {
            Text(issuedToken ?? "")
        }
        .confirmationDialog(
            pendingAction?.title ?? "",
            isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
            titleVisibility: .visible
        ) {
            if let p = pendingAction {
                Button(p.buttonLabel, role: p.destructive ? .destructive : .none) {
                    Task { await runPending(p) }
                }
                Button("取消", role: .cancel) { pendingAction = nil }
            }
        } message: {
            if let p = pendingAction { Text(p.message) }
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private func profileCard(_ u: AdminUserDTO) -> some View {
        card(title: "Profile", icon: "person.crop.circle.fill", tint: AppColors.primaryAction) {
            infoRow("ID", u.id, mono: true)
            infoRow("Email", u.email ?? "未设置")
            infoRowRaw("角色", AnyView(roleBadge(u.role)))
            infoRowRaw("状态", AnyView(statusBadge(u.status)))
            infoRow("创建", formatDate(u.createdAt))
            infoRow("最近登录", formatDate(u.lastLoginAt))
        }
    }

    @ViewBuilder
    private func summaryCard(_ u: AdminUserDTO) -> some View {
        card(title: "摘要", icon: "chart.bar.doc.horizontal", tint: AppColors.metricPrimary) {
            infoRow("任务数", "\(u.jobCount ?? 0)")
            infoRow("累计成本", formatCost(u.totalCost))
            infoRow("最近活跃", formatDate(u.lastActiveAt))
        }
    }

    @ViewBuilder
    private func roleSection(_ u: AdminUserDTO) -> some View {
        card(title: "角色管理", icon: "key.horizontal", tint: AppColors.info) {
            Picker("角色", selection: $draftRole) {
                Text("Member").tag("member")
                Text("Admin").tag("admin")
            }
            .pickerStyle(.segmented)

            Button {
                Task { await setRole(u) }
            } label: {
                Text("保存角色")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draftRole == (u.role ?? "member"))
        }
    }

    @ViewBuilder
    private func tokenSection(_ u: AdminUserDTO) -> some View {
        card(title: "账号 Token", icon: "key.fill", tint: AppColors.metricTertiary) {
            Text("为该账号签发一枚新的访问 token，用于管理端或客户端登录。生成后仅显示一次。")
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)

            HStack(spacing: Spacing.sm) {
                Button {
                    pendingAction = .createToken(userId: u.id, name: u.displayName ?? u.id)
                } label: {
                    Label("签发 Token", systemImage: "plus.rectangle.fill.on.rectangle.fill")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                Button(role: u.status == "active" ? .destructive : .none) {
                    if u.status == "active" {
                        pendingAction = .suspend(userId: u.id, name: u.displayName ?? u.id)
                    } else {
                        pendingAction = .activate(userId: u.id, name: u.displayName ?? u.id)
                    }
                } label: {
                    Label(
                        u.status == "active" ? "暂停账号" : "重新激活",
                        systemImage: u.status == "active" ? "pause.circle" : "play.circle.fill"
                    )
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var usageCard: some View {
        card(title: "Usage (近 30 天)", icon: "chart.line.uptrend.xyaxis", tint: AppColors.metricWarm) {
            if usage.isEmpty {
                Text("没有使用数据。")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.neutral)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(Array(usage.enumerated()), id: \.offset) { _, entry in
                        usageRow(entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func usageRow(_ e: AdminUsageEntryDTO) -> some View {
        HStack(spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 1) {
                Text(e.model)
                    .font(AppTypography.captionMono)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(e.callCount ?? 0) 次 · 输入 \(Self.formatTokens(e.inputTokens ?? 0)) · 输出 \(Self.formatTokens(e.outputTokens ?? 0))")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
            Spacer()
            Text(formatCost(e.totalCost))
                .font(AppTypography.captionMono)
                .foregroundStyle(AppColors.metricPrimary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func deleteSection(_ u: AdminUserDTO) -> some View {
        VStack(spacing: Spacing.xs) {
            Button(role: .destructive) {
                pendingAction = .delete(userId: u.id, name: u.displayName ?? u.id)
            } label: {
                Label("删除用户", systemImage: "trash")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.danger)

            Text("删除不可恢复。用户的历史用量记录仍会保留在数据库中。")
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Chrome

    @ViewBuilder
    private func card<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(AppTypography.captionBold)
                Spacer()
            }
            content()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(Color(.systemBackground))
        )
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(mono ? AppTypography.captionMono : AppTypography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func infoRowRaw(_ label: String, _ value: AnyView) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
                .frame(width: 72, alignment: .leading)
            value
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func roleBadge(_ role: String?) -> some View {
        let r = (role ?? "member").lowercased()
        let tint: Color = r == "admin" ? AppColors.danger : AppColors.metricPrimary
        Text(r.capitalized)
            .font(AppTypography.nano)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
    }

    @ViewBuilder
    private func statusBadge(_ status: String?) -> some View {
        let value = (status ?? "unknown").lowercased()
        let tint: Color = {
            switch value {
            case "active":      return AppColors.success
            case "suspended":   return AppColors.warning
            case "banned":      return AppColors.danger
            default:            return AppColors.neutral
            }
        }()
        Text(value.capitalized)
            .font(AppTypography.nano)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
    }

    // MARK: - Helpers

    private func formatCost(_ raw: String?) -> String {
        guard let s = raw, let v = Double(s) else { return "$0.00" }
        return String(format: "$%.2f", v)
    }

    private func formatDate(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        if let d = ISO8601DateFormatter().date(from: iso) {
            return Formatters.relativeString(for: d)
        }
        return iso
    }

    private static func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return String(n)
    }

    // MARK: - Data

    private func load() async {
        loading = true
        defer { loading = false }
        async let detail: AdminUserDTO? = try? adminVM.loadUserDetail(id: userId)
        async let usageResp: AdminUsageResponseDTO? = try? adminVM.loadUserUsage(userId: userId, period: "month")
        let u = await detail
        let usageBody = await usageResp
        if let u {
            user = u
            draftRole = u.role ?? "member"
        }
        usage = (usageBody?.usage ?? []).sorted { ($0.totalCost ?? "0").compare($1.totalCost ?? "0", options: .numeric) == .orderedDescending }
    }

    private func setRole(_ u: AdminUserDTO) async {
        do {
            try await adminVM.setUserRole(id: u.id, role: draftRole)
            await load()
            Haptics.shared.success()
        } catch {
            actionError = error.localizedDescription
            Haptics.shared.error()
        }
    }

    private func runPending(_ action: PendingAction) async {
        pendingAction = nil
        do {
            switch action {
            case .suspend(let id, _):
                try await adminVM.suspendUser(id: id)
            case .activate(let id, _):
                try await adminVM.activateUser(id: id)
            case .createToken(let id, let name):
                if let token = try await adminVM.createToken(userId: id, name: "iOS-\(name)") {
                    issuedToken = token
                }
            case .delete(let id, _):
                try await adminVM.deleteUser(id: id)
                dismiss()
                return
            }
            await load()
            Haptics.shared.success()
        } catch {
            actionError = error.localizedDescription
            Haptics.shared.error()
        }
    }

    enum PendingAction: Identifiable {
        case suspend(userId: String, name: String)
        case activate(userId: String, name: String)
        case createToken(userId: String, name: String)
        case delete(userId: String, name: String)

        var id: String {
            switch self {
            case .suspend(let u, _):       return "suspend-\(u)"
            case .activate(let u, _):      return "activate-\(u)"
            case .createToken(let u, _):   return "token-\(u)"
            case .delete(let u, _):        return "delete-\(u)"
            }
        }
        var title: String {
            switch self {
            case .suspend:       return "暂停账号"
            case .activate:      return "重新激活"
            case .createToken:   return "签发 Token"
            case .delete:        return "删除用户"
            }
        }
        var message: String {
            switch self {
            case .suspend(_, let n):     return "暂停后 “\(n)” 将无法登录，但历史数据保留。可以随时重新激活。"
            case .activate(_, let n):    return "将重新启用 “\(n)” 的账号访问。"
            case .createToken(_, let n): return "将为 “\(n)” 签发一枚新的 token，仅在下一屏显示一次。"
            case .delete(_, let n):      return "将永久删除 “\(n)”。此操作不可撤销。"
            }
        }
        var buttonLabel: String {
            switch self {
            case .suspend:       return "暂停"
            case .activate:      return "激活"
            case .createToken:   return "签发"
            case .delete:        return "删除"
            }
        }
        var destructive: Bool {
            switch self {
            case .suspend, .delete: return true
            default: return false
            }
        }
    }
}
