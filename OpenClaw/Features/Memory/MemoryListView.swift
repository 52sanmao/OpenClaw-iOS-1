import SwiftUI

/// 记忆管理视图 — 展示和管理上下文记忆
struct MemoryListView: View {
    @Bindable var vm: MemoryViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if vm.isLoadingMemories {
                    ProgressView("加载记忆中…")
                        .padding(.top, Spacing.xl)
                } else if vm.memories.isEmpty {
                    ContentUnavailableView(
                        "暂无记忆",
                        systemImage: "brain.head.profile",
                        description: Text("记忆系统将自动记录重要的上下文信息。")
                    )
                } else {
                    memoryList
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "记忆") {
                    Text("\(vm.memories.count) 条记忆")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
        .refreshable {
            await vm.loadMemories()
            Haptics.shared.refreshComplete()
        }
        .task {
            if vm.memories.isEmpty && !vm.isLoadingMemories {
                await vm.loadMemories()
            }
        }
    }

    @ViewBuilder
    private var memoryList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(AppColors.info)
                Text("上下文记忆")
                    .font(AppTypography.captionBold)
                Spacer()
                Text("\(vm.memories.count) 条")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(vm.memories) { memory in
                    memoryRow(memory)
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
    private func memoryRow(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(memoryTypeTint(memory.type).opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: memoryTypeIcon(memory.type))
                        .foregroundStyle(memoryTypeTint(memory.type))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(memory.name)
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(memory.type.capitalized)
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                }
                Spacer()
            }

            if let desc = memory.description, !desc.isEmpty {
                Text(desc)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(3)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color(.systemGroupedBackground))
        )
    }

    private func memoryTypeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "user": return "person.circle.fill"
        case "feedback": return "bubble.left.and.exclamationmark.bubble.right.fill"
        case "project": return "folder.fill"
        case "reference": return "link.circle.fill"
        default: return "brain.head.profile"
        }
    }

    private func memoryTypeTint(_ type: String) -> Color {
        switch type.lowercased() {
        case "user": return AppColors.metricPrimary
        case "feedback": return AppColors.warning
        case "project": return AppColors.info
        case "reference": return AppColors.metricTertiary
        default: return AppColors.neutral
        }
    }
}
