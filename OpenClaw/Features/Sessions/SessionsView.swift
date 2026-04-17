import SwiftUI

struct SessionsView: View {
    @State var vm: SessionsViewModel
    let repository: SessionRepository
    var client: GatewayClientProtocol?
    @State private var selectedTab: SessionTab = .chat

    enum SessionTab: String, CaseIterable {
        case chat = "聊天历史"
        case subagents = "子代理"
    }

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            Picker("会话类型", selection: $selectedTab) {
                ForEach(SessionTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)

            switch selectedTab {
            case .chat:
                chatSection
            case .subagents:
                subagentsSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "会话") {
                    sessionSubtitle
                }
            }
        }
        }
        .task { await vm.load() }
    }

    // MARK: - Chat History

    @ViewBuilder
    private var chatSection: some View {
        if vm.isLoading && vm.mainSession == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let main = vm.mainSession {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    MainSessionCard(session: main, repository: repository, client: client)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .refreshable {
                await vm.load()
                Haptics.shared.refreshComplete()
            }
        } else if let err = vm.error {
            List {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CardErrorView(error: err, minHeight: 60)
                    Text("会话页优先使用 sessions_list / sessions_history；若服务器未启用扩展接口，会自动回退到 /api/chat/threads 与 /api/chat/history。请查看右下角日志确认当前走的是哪条路径。")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
                .padding(.vertical, Spacing.xxs)
            }
            .listStyle(.insetGrouped)
        } else {
            ContentUnavailableView(
                "暂无会话",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("未找到活动中的聊天会话。")
            )
        }
    }

    // MARK: - Subagents

    @ViewBuilder
    private var subagentsSection: some View {
        if vm.isLoading && vm.subagents.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !vm.subagents.isEmpty {
            List {
                Section("子代理会话") {
                    ForEach(vm.subagents) { session in
                        NavigationLink {
                            SessionTraceView(
                                sessionKey: session.traceLookupKey,
                                title: session.displayName,
                                subtitle: session.updatedAtFormatted,
                                repository: repository,
                                client: client
                            )
                        } label: {
                            SubagentRow(session: session)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await vm.load()
                Haptics.shared.refreshComplete()
            }
        } else if let err = vm.error {
            List {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CardErrorView(error: err, minHeight: 60)
                    Text("子代理列表与轨迹页同样支持从扩展接口回退到线程历史。请查看右下角日志，确认失败发生在 sessions_list、sessions_history 还是底层 /api/chat/history。")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
                .padding(.vertical, Spacing.xxs)
            }
            .listStyle(.insetGrouped)
        } else {
            ContentUnavailableView(
                "暂无子代理",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text("未找到子代理会话。")
            )
        }
    }

    @ViewBuilder
    private var sessionSubtitle: some View {
        if let main = vm.mainSession {
            HStack(spacing: Spacing.xs) {
                Text(main.status == .running ? "运行中" : "空闲")
                    .font(AppTypography.micro)
                    .foregroundStyle(main.status == .running ? AppColors.success : AppColors.neutral)
                Text("\u{00B7} \(Formatters.tokens(main.totalTokens))")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
        } else if vm.isLoading {
            Text("加载中…")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
        }
    }
}

// MARK: - Subagent Row

private struct SubagentRow: View {
    let session: SessionEntry

    var body: some View {
        HStack(spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(session.displayName)
                    .font(AppTypography.body)
                    .lineLimit(1)

                HStack(spacing: Spacing.sm) {
                    if let model = session.model {
                        ModelPill(model: model)
                    }
                    Label(Formatters.tokens(session.totalTokens), systemImage: "number.circle")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.metricPrimary)
                    Spacer()
                    Text(session.updatedAtFormatted)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
