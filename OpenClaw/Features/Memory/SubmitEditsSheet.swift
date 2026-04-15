import MarkdownUI
import SwiftUI

struct SubmitEditsSheet: View {
    var vm: MemoryViewModel
    let file: MemoryFile
    var skillEntry: SkillFileEntry?
    @Environment(\.dismiss) private var dismiss

    private var hasResult: Bool { vm.submitResult != nil }

    var body: some View {
        NavigationStack {
            List {
                // Comment queue — swipe to delete before submitting
                if !hasResult {
                    Section("你的评论（\(vm.comments.count)）") {
                        ForEach(vm.comments) { comment in
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(comment.lineStart == comment.lineEnd
                                     ? "第 \(comment.lineStart + 1) 行"
                                     : "第 \(comment.lineStart + 1)–\(comment.lineEnd + 1) 行")
                                    .font(AppTypography.micro)
                                    .foregroundStyle(AppColors.neutral)
                                Text(comment.paragraphPreview)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.neutral)
                                    .lineLimit(2)
                                Text(comment.text)
                                    .font(AppTypography.body)
                            }
                            .padding(.vertical, Spacing.xxs)
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.map { vm.comments[$0].id }
                            ids.forEach { vm.removeComment($0) }
                            if vm.comments.isEmpty { dismiss() }
                        }
                    }
                }

                if vm.isSubmitting {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: Spacing.xs) {
                                ProgressView()
                                Text("代理正在编辑…")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.neutral)
                                ElapsedTimer()
                            }
                            Spacer()
                        }
                        .padding(.vertical, Spacing.md)
                    }
                }

                if let response = vm.submitResult {
                    Section("代理响应") {
                        Markdown(response)
                            .markdownTheme(.openClaw)
                            .textSelection(.enabled)
                    }
                }

                if let error = vm.submitError {
                    Section {
                        ErrorLabel(error: error)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("提交修改")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if hasResult {
                        Button("完成") {
                            vm.clearComments()
                            dismiss()
                            Task { await reloadFile() }
                        }
                    } else {
                        Button {
                            Task { await vm.submitEdits(for: file) }
                        } label: {
                            if vm.isSubmitting {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text("提交")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(vm.isSubmitting || vm.comments.isEmpty)
                    }
                }
            }
        }
    }

    private func reloadFile() async {
        if let entry = skillEntry {
            await vm.loadSkillFileContent(entry)
        } else {
            await vm.loadFile(file)
        }
    }
}
