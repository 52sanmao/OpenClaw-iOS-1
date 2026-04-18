import SwiftUI

struct MemoryTab: View {
    @State var vm: MemoryViewModel
    @State private var selectedTab: WorkspaceTab = .memory
    @State private var showActions = false

    enum WorkspaceTab: String, CaseIterable {
        case memory = "记忆"
        case skills = "技能"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视图", selection: $selectedTab) {
                    ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

                switch selectedTab {
                case .memory:
                    memoryList
                case .skills:
                    skillsList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DetailTitleView(title: "记忆与技能") {
                        memSubtitle
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showActions = true } label: {
                        Image(systemName: "wand.and.stars")
                    }
                }
            }
            .sheet(isPresented: $showActions) {
                MemoryActionSheet(tab: selectedTab, vm: vm)
            }
        }
        .task { await vm.loadFiles() }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .skills && (vm.skills.isEmpty || vm.skillError != nil) && !vm.isLoadingSkills {
                Task { await vm.loadSkills() }
            }
        }
    }

    // MARK: - Memory List

    @ViewBuilder
    private var memoryList: some View {
        List {
            if !bootstrapFiles.isEmpty {
                Section("记忆文件") {
                    ForEach(bootstrapFiles) { file in
                        NavigationLink {
                            MemoryFileView(vm: vm, file: file)
                        } label: {
                            FileRow(file: file)
                        }
                    }
                }
            }

            if !dailyLogs.isEmpty {
                Section("每日日志") {
                    ForEach(dailyLogs) { file in
                        NavigationLink {
                            MemoryFileView(vm: vm, file: file)
                        } label: {
                            FileRow(file: file)
                        }
                    }
                }
            }

            if !referenceFiles.isEmpty {
                Section("参考资料") {
                    ForEach(referenceFiles) { file in
                        NavigationLink {
                            MemoryFileView(vm: vm, file: file)
                        } label: {
                            FileRow(file: file)
                        }
                    }
                }
            }

            if vm.isLoadingFiles {
                CardLoadingView(minHeight: 60)
            } else if let err = vm.fileError {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CardErrorView(error: err, minHeight: 60)
                    Text("记忆文件依赖 memory-list / memory_get / file-read。请查看右下角日志确认失败在列表、读取还是服务端未启用接口。")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
                .padding(.vertical, Spacing.xxs)
            } else if vm.files.isEmpty {
                ContentUnavailableView(
                    "没有文件",
                    systemImage: "doc.text",
                    description: Text("未找到工作区文件。")
                )
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await vm.loadFiles()
            Haptics.shared.refreshComplete()
        }
    }

    @ViewBuilder
    private var skillsList: some View {
        if !vm.skills.isEmpty {
            SkillsListView(vm: vm)
        } else if vm.isLoadingSkills {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.skillError {
            List {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CardErrorView(error: err, minHeight: 60)
                    Text("技能页依赖 skills-list / skill-files / skill-read。请查看右下角日志确认是目录读取失败，还是当前部署未启用 stats/exec。")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
                .padding(.vertical, Spacing.xxs)
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await vm.loadSkills()
                Haptics.shared.refreshComplete()
            }
        } else {
            SkillsListView(vm: vm)
        }
    }

    private var bootstrapFiles: [MemoryFile] { vm.files.filter { $0.kind == .bootstrap } }
    private var dailyLogs: [MemoryFile] { vm.files.filter { $0.kind == .dailyLog } }
    private var referenceFiles: [MemoryFile] { vm.files.filter { $0.kind == .reference } }

    @ViewBuilder
    private var memSubtitle: some View {
        let fileCount = vm.files.count
        let skillCount = vm.skills.count
        if fileCount > 0 || skillCount > 0 {
            HStack(spacing: Spacing.xs) {
                Text("\(fileCount) 个文件")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                if skillCount > 0 {
                    Text("· \(skillCount) 个技能")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        } else if vm.isLoadingFiles {
            Text("加载中…")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
        }
    }
}

struct FileRow: View {
    let file: MemoryFile

    var body: some View {
        Label {
            Text(file.name)
                .font(AppTypography.body)
        } icon: {
            Image(systemName: file.icon)
                .foregroundStyle(AppColors.primaryAction)
        }
    }
}
