import SwiftUI

/// Shows all files inside a skill folder, grouped by type.
struct SkillDetailView: View {
    var vm: MemoryViewModel
    let skill: SkillFile
    @State private var showSkillComment = false

    private var markdownFiles: [SkillFileEntry] { vm.skillFiles.filter(\.isMarkdown) }
    private var otherFiles: [SkillFileEntry] { vm.skillFiles.filter { !$0.isMarkdown } }

    var body: some View {
        Group {
            if vm.isLoadingSkillFiles && vm.skillFiles.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.skillFilesError, vm.skillFiles.isEmpty {
                ContentUnavailableView(
                    "无法加载技能文件",
                    systemImage: "exclamationmark.triangle",
                    description: Text(err.localizedDescription)
                )
            } else if vm.skillFiles.isEmpty && !vm.isLoadingSkillFiles {
                ContentUnavailableView(
                    "技能内容为空",
                    systemImage: "folder",
                    description: Text("当前技能目录下没有可展示的文件。")
                )
            } else {
                List {
                    if !markdownFiles.isEmpty {
                        Section("文档") {
                            ForEach(markdownFiles) { entry in
                                NavigationLink {
                                    MemoryFileView(
                                        vm: vm,
                                        file: MemoryFile(id: entry.id, name: entry.name, path: entry.absolutePath, kind: .reference),
                                        skillEntry: entry
                                    )
                                } label: {
                                    SkillFileRow(entry: entry)
                                }
                            }
                        }
                    }

                    if !otherFiles.isEmpty {
                        Section("脚本与配置") {
                            ForEach(otherFiles) { entry in
                                NavigationLink {
                                    ReadOnlyFileView(vm: vm, entry: entry)
                                } label: {
                                    SkillFileRow(entry: entry)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: skill.displayName) {
                    if vm.isLoadingSkillFiles && vm.skillFiles.isEmpty {
                        Text("加载技能文件中…")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    } else {
                        Text("\(vm.skillFiles.count) 个文件")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.neutral)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showSkillComment = true } label: {
                    Image(systemName: "text.bubble")
                }
            }
        }
        .sheet(isPresented: $showSkillComment) {
            CommentSheet(mode: .skill(
                skill: skill,
                files: vm.skillFiles.map(\.id),
                vm: vm
            ))
        }
        .refreshable {
            await vm.loadSkillFiles(skill)
            Haptics.shared.refreshComplete()
        }
        .task { await vm.loadSkillFiles(skill) }
    }
}

private struct SkillFileRow: View {
    let entry: SkillFileEntry

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(entry.name)
                    .font(AppTypography.body)
                if entry.id.contains("/") {
                    Text(entry.id)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        } icon: {
            Image(systemName: entry.isMarkdown ? "doc.text.fill" : "doc.fill")
                .foregroundStyle(entry.isMarkdown ? AppColors.primaryAction : AppColors.neutral)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
