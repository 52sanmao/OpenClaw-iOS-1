import SwiftUI

/// Skills browser — lists skill folders, taps to view all files inside.
struct SkillsListView: View {
    var vm: MemoryViewModel

    var body: some View {
        Group {
            if !vm.skills.isEmpty {
                List {
                    Section("技能文件") {
                        ForEach(vm.skills) { skill in
                            NavigationLink {
                                SkillDetailView(vm: vm, skill: skill)
                            } label: {
                                SkillRow(skill: skill)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else if vm.isLoadingSkills {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.skillError {
                List {
                    CardErrorView(error: err, minHeight: 60)
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView(
                    "没有技能",
                    systemImage: "bolt.fill",
                    description: Text("当前未找到技能定义。")
                )
            }
        }
        .refreshable {
            await vm.loadSkills()
            Haptics.shared.refreshComplete()
        }
    }
}

private struct SkillRow: View {
    let skill: SkillFile

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(skill.displayName)
                    .font(AppTypography.body)
                Text(skill.id)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
        } icon: {
            Image(systemName: "bolt.circle.fill")
                .foregroundStyle(AppColors.metricTertiary)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
