import MarkdownUI
import SwiftUI

struct MemoryFileView: View {
    var vm: MemoryViewModel
    let file: MemoryFile
    /// Optional skill entry — when set, uses skill-read instead of memory_get.
    var skillEntry: SkillFileEntry?

    @State private var draftText = ""
    @State private var showPageComment = false
    @FocusState private var isEditorFocused: Bool

    private var isEditableMemory: Bool { skillEntry == nil }
    private var baselineText: String { vm.fileContent?.text ?? "" }
    private var hasDraftChanges: Bool { isEditableMemory && draftText != baselineText }

    var body: some View {
        Group {
            if vm.isLoadingContent || (vm.fileContent == nil && vm.contentError == nil) {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.contentError {
                ContentUnavailableView(
                    "无法加载内容",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
                .overlay(alignment: .bottom) {
                    Text(loadHint)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.md)
                }
            } else if let content = vm.fileContent {
                if isEditableMemory {
                    editableContent(content)
                } else {
                    skillMarkdownContent(content)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: file.name) {
                    Text(skillEntry?.id ?? file.path)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(1)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if isEditableMemory {
                    Button {
                        isEditorFocused = false
                        Task { await vm.submitDraftEdits(for: file, text: draftText) }
                    } label: {
                        if vm.isSubmitting {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(vm.isSubmitting || !hasDraftChanges)
                } else {
                    Button { showPageComment = true } label: {
                        Image(systemName: "text.bubble")
                    }
                }
            }
        }
        .sheet(isPresented: $showPageComment) {
            CommentSheet(mode: .page(fileName: file.name, filePath: file.path, vm: vm))
        }
        .task {
            if let entry = skillEntry {
                await vm.loadSkillFileContent(entry)
            } else {
                await vm.loadFile(file)
            }
        }
        .onChange(of: vm.fileContent?.text ?? "") { _, newValue in
            guard isEditableMemory else { return }
            draftText = newValue
        }
        .onChange(of: draftText) { _, _ in
            guard isEditableMemory, hasDraftChanges else { return }
            vm.clearSubmitState()
        }
    }

    private func editableContent(_ content: MemoryFileContent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Label("直接编辑", systemImage: "square.and.pencil")
                    .font(AppTypography.captionBold)
                    .foregroundStyle(AppColors.primaryAction)
                Spacer()
                Text(hasDraftChanges ? "未保存" : "已同步")
                    .font(AppTypography.micro)
                    .foregroundStyle(hasDraftChanges ? AppColors.warning : AppColors.success)
            }

            Text("像记事本一样直接修改正文，完成后点右上角保存。")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)

            TextEditor(text: $draftText)
                .focused($isEditorFocused)
                .font(AppTypography.body)
                .scrollContentBackground(.hidden)
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(Color(.systemBackground))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .strokeBorder(AppColors.neutral.opacity(0.12))
                }

            if vm.isSubmitting || vm.submitResult != nil || vm.submitError != nil {
                saveStatusCard
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColors.neutral.opacity(0.03))
    }

    private func skillMarkdownContent(_ content: MemoryFileContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Markdown(content.text)
                    .markdownTheme(.openClaw)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(Color(.systemBackground))
                    )

                Text("技能文档保持只读；如需修改，请用右上角批注让代理处理。")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(AppColors.neutral.opacity(0.03))
    }

    @ViewBuilder
    private var saveStatusCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if vm.isSubmitting {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("正在保存到工作区…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.neutral)
                    Spacer()
                    ElapsedTimer()
                }
            }

            if let response = vm.submitResult {
                Label("已保存", systemImage: "checkmark.circle.fill")
                    .font(AppTypography.captionBold)
                    .foregroundStyle(AppColors.success)
                Markdown(response)
                    .markdownTheme(.openClaw)
            }

            if let error = vm.submitError {
                ErrorLabel(error: error)
            }
        }
        .padding(Spacing.sm)
        .background(AppColors.neutral.opacity(0.06), in: RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private var loadHint: String {
        if let skillEntry {
            return "该页面依赖 skill-read 读取技能文件。请查看右下角日志确认失败在 skill-files、skill-read，还是当前服务器未启用 stats/exec。"
        }
        if file.path.hasPrefix("memory/") || file.path == "MEMORY.md" {
            return "该页面优先通过 memory_get 读取记忆内容；若失败，请查看右下角日志确认是 tool 接口失败还是服务端返回空内容。"
        }
        return "该页面通过 file-read 读取根目录文件。请查看右下角日志确认服务端是否启用了 stats/exec 文件读取命令。"
    }
}
