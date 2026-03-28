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
                    "Cannot Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(err.localizedDescription)
                )
            } else if vm.skillFiles.isEmpty && !vm.isLoadingSkillFiles {
                ContentUnavailableView(
                    "Empty Skill",
                    systemImage: "folder",
                    description: Text("No files found in this skill.")
                )
            } else {
                List {
                    if !markdownFiles.isEmpty {
                        Section("Documents") {
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
                        Section("Scripts & Config") {
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
        .navigationTitle(skill.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
