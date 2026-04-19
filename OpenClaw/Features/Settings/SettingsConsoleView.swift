import SwiftUI

struct SettingsConsoleView: View {
    let accountStore: AccountStore
    let client: GatewayClientProtocol
    let memoryVM: MemoryViewModel

    @State private var toolsVM: ToolsConfigViewModel
    @State private var commandsVM: CommandsViewModel
    @State private var selectedSection: SettingsConsoleSection

    init(accountStore: AccountStore, client: GatewayClientProtocol, memoryVM: MemoryViewModel, initialSection: SettingsConsoleSection = .network) {
        self.accountStore = accountStore
        self.client = client
        self.memoryVM = memoryVM
        _toolsVM = State(initialValue: ToolsConfigViewModel(client: client))
        _commandsVM = State(initialValue: CommandsViewModel(client: client, cronRepository: RemoteCronRepository(client: client), cronDetailRepository: RemoteCronDetailRepository(client: client)))
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        List {
            sectionPicker

            switch selectedSection {
            case .network:
                networkSection
            case .commands:
                commandsSection
            case .users:
                usersSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "设置") {
                    Text(selectedSection.subtitle)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
        .task {
            if toolsVM.config == nil && !toolsVM.isLoading {
                await toolsVM.load()
            }
        }
        .refreshable {
            async let tools: Void = toolsVM.load()
            _ = await tools
            Haptics.shared.refreshComplete()
        }
    }

    private var sectionPicker: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(SettingsConsoleSection.allCases) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: section.icon)
                                    .font(AppTypography.nano)
                                Text(section.title)
                                    .font(AppTypography.nano)
                            }
                            .foregroundStyle(selectedSection == section ? Color.white : AppColors.neutral)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(selectedSection == section ? AppColors.primaryAction : AppColors.neutral.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, Spacing.xxs)
            }
        } header: {
            Text("设置域")
        }
    }

    private var networkSection: some View {
        Group {
            Section("连接与诊断") {
                navigationSummaryRow(
                    title: "当前账号",
                    value: accountStore.activeAccount?.name ?? "未配置",
                    detail: accountStore.activeAccount?.displayURL ?? "请先添加网关账号",
                    icon: "network",
                    tint: AppColors.info
                )

                navigationSummaryRow(
                    title: "调试状态",
                    value: AppDebugSettings.debugEnabled ? "已开启" : "已关闭",
                    detail: AppDebugSettings.debugEnabled ? "日志浮窗、调试输出与诊断详情均已启用" : "当前只保留正常运行所需界面",
                    icon: AppDebugSettings.debugEnabled ? "ladybug.fill" : "ladybug",
                    tint: AppDebugSettings.debugEnabled ? AppColors.warning : AppColors.neutral
                )
            }

            Section("诊断入口") {
                NavigationLink {
                    SettingsView(accountStore: accountStore, client: client)
                } label: {
                    settingsRow(
                        title: "连接与诊断",
                        subtitle: "测试连接、查看诊断详情与调试状态",
                        icon: "heart.text.square.fill",
                        tint: AppColors.info
                    )
                }

                NavigationLink {
                    ToolsConfigView(client: client)
                } label: {
                    settingsRow(
                        title: "工具配置",
                        subtitle: "查看原生工具、权限白名单与链路状态",
                        icon: "wrench.and.screwdriver.fill",
                        tint: AppColors.metricPrimary
                    )
                }
            }
        }
    }

    private var commandsSection: some View {
        Group {
            Section("命令中心") {
                navigationSummaryRow(
                    title: "快捷命令",
                    value: "\(QuickCommand.visibleCount) 个",
                    detail: "重启、体检、日志尾部、状态、安全、备份",
                    icon: "terminal.fill",
                    tint: AppColors.metricWarm
                )
                navigationSummaryRow(
                    title: "完整命令集",
                    value: "\(QuickCommand.all.count) 个",
                    detail: "包含定时任务暂停、渠道检查、索引重建等运维动作",
                    icon: "switch.2",
                    tint: AppColors.primaryAction
                )
            }

            Section {
                CommandsCard(vm: commandsVM)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section("深度管理") {
                NavigationLink {
                    CommandsDetailView(commandsVM: commandsVM, client: client)
                } label: {
                    settingsRow(
                        title: "命令与管理",
                        subtitle: "查看全部命令、模型配置与频道状态",
                        icon: "slider.horizontal.below.rectangle",
                        tint: AppColors.metricHighlight
                    )
                }
            }
        }
    }

    private var usersSection: some View {
        Section("用户管理") {
            NavigationLink {
                SettingsView(accountStore: accountStore, client: client)
            } label: {
                settingsRow(
                    title: "账号与调试",
                    subtitle: "\(accountStore.accounts.count) 个账号",
                    icon: "person.crop.circle.fill",
                    tint: AppColors.success
                )
            }
        }
    }

    private func settingsRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.tintedBackground(tint, opacity: 0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(AppTypography.caption)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppTypography.body)
                Text(subtitle)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func navigationSummaryRow(title: String, value: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.tintedBackground(tint, opacity: 0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(AppTypography.caption)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(.primary)
                Text(value)
                    .font(AppTypography.body)
                    .foregroundStyle(tint)
                Text(detail)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
            Spacer(minLength: Spacing.sm)
        }
        .padding(.vertical, Spacing.xxs)
    }
}

enum SettingsConsoleSection: String, CaseIterable, Identifiable {
    case network
    case commands
    case users

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network: "网络"
        case .commands: "命令"
        case .users: "用户"
        }
    }

    var subtitle: String {
        switch self {
        case .network: "连接测试、诊断链路与调试状态"
        case .commands: "快捷运维命令与完整管理入口"
        case .users: "账号切换、调试与连接测试"
        }
    }

    var icon: String {
        switch self {
        case .network: "network"
        case .commands: "terminal.fill"
        case .users: "person.crop.circle.fill"
        }
    }
}
