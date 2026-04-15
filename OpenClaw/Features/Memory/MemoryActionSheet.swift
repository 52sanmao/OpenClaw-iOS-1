import MarkdownUI
import SwiftUI

/// Action picker + execution sheet for memory/skills maintenance tasks.
struct MemoryActionSheet: View {
    let tab: MemoryTab.WorkspaceTab
    var vm: MemoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAction: MemoryAction?
    @State private var isRunning = false
    @State private var result: String?
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            List {
                if result == nil && !isRunning {
                    Section("选择操作") {
                        ForEach(actions) { action in
                            Button {
                                selectedAction = action
                                Task { await run(action) }
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: action.icon)
                                        .font(AppTypography.statusIcon)
                                        .foregroundStyle(action.color)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(action.name)
                                            .font(AppTypography.body)
                                            .fontWeight(.medium)
                                        Text(action.description)
                                            .font(AppTypography.micro)
                                            .foregroundStyle(AppColors.neutral)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, Spacing.xxs)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if isRunning {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: Spacing.xs) {
                                ProgressView()
                                Text(selectedAction?.loadingText ?? "正在执行…")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.neutral)
                                ElapsedTimer()
                            }
                            Spacer()
                        }
                        .padding(.vertical, Spacing.md)
                    }
                }

                if let response = result {
                    Section("代理响应") {
                        Markdown(response)
                            .markdownTheme(.openClaw)
                            .textSelection(.enabled)
                    }
                }

                if let error {
                    Section {
                        ErrorLabel(error: error)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result != nil || error != nil ? "完成" : "取消") { dismiss() }
                }
            }
        }
    }

    // MARK: - Actions per tab

    private var actions: [MemoryAction] {
        switch tab {
        case .memory:
            return [
                MemoryAction(
                    id: "full-cleanup",
                    name: "完整清理",
                    description: "先读取文档，更新今日内容，再清理全部记忆文件",
                    icon: "sparkles",
                    color: AppColors.metricTertiary,
                    loadingText: "代理正在读取文档并清理全部记忆…",
                    prompt: PromptTemplates.memoryFullCleanup
                ),
                MemoryAction(
                    id: "today-cleanup",
                    name: "今日清理",
                    description: "先读取文档，仅更新今天的记忆",
                    icon: "calendar.badge.clock",
                    color: AppColors.primaryAction,
                    loadingText: "代理正在更新今天的记忆…",
                    prompt: PromptTemplates.memoryTodayCleanup
                ),
            ]
        case .skills:
            return []
        }
    }

    // MARK: - Execute

    private func run(_ action: MemoryAction) async {
        isRunning = true
        error = nil
        result = nil

        let prompt = action.prompt()
        await vm.runMaintenanceAction(prompt: prompt)

        result = vm.maintenanceResult
        error = vm.maintenanceError
        isRunning = false
    }
}

// MARK: - Action Model

struct MemoryAction: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let loadingText: String
    let prompt: () -> (system: String, user: String)
}
