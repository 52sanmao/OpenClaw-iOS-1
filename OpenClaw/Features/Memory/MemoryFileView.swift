import MarkdownUI
import SwiftUI

struct MemoryFileView: View {
    var vm: MemoryViewModel
    let file: MemoryFile
    @State private var commentTarget: MemoryParagraph?
    @State private var showSubmitSheet = false

    var body: some View {
        Group {
            if vm.isLoadingContent || (vm.fileContent == nil && vm.contentError == nil) {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.contentError {
                ContentUnavailableView(
                    "Cannot Load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else if let content = vm.fileContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(content.paragraphs) { para in
                            ParagraphRow(
                                paragraph: para,
                                comments: vm.commentsForParagraph(para.id),
                                onAddComment: { commentTarget = para },
                                onRemoveComment: { vm.removeComment($0) }
                            )
                            Divider().padding(.horizontal, Spacing.md)
                        }
                    }
                }
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !vm.comments.isEmpty {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showSubmitSheet = true
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "paperplane.fill")
                            Text("\(vm.comments.count)")
                        }
                        .foregroundStyle(AppColors.primaryAction)
                    }
                }
            }
        }
        .sheet(item: $commentTarget) { para in
            AddCommentSheet(paragraphPreview: para.text) { text in
                vm.addComment(
                    paragraphId: para.id,
                    lineStart: para.lineStart,
                    lineEnd: para.lineEnd,
                    text: text,
                    preview: para.text
                )
                commentTarget = nil
            }
        }
        .sheet(isPresented: $showSubmitSheet) {
            SubmitEditsSheet(vm: vm, file: file)
        }
        .task { await vm.loadFile(file) }
    }
}

// MARK: - Paragraph Row

private struct ParagraphRow: View {
    let paragraph: MemoryParagraph
    let comments: [MemoryComment]
    let onAddComment: () -> Void
    let onRemoveComment: (UUID) -> Void

    private var hasComments: Bool { !comments.isEmpty }

    var body: some View {
        HStack(spacing: 0) {
            // Gutter — highlighted accent bar when paragraph has comments
            RoundedRectangle(cornerRadius: 2)
                .fill(hasComments ? AppColors.metricWarm : .clear)
                .frame(width: 3)
                .padding(.vertical, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Content — tinted background when has comments
                Markdown(paragraph.text)
                    .markdownTheme(.openClaw)
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        hasComments
                            ? AppColors.tintedBackground(AppColors.metricWarm, opacity: 0.06)
                            : .clear,
                        in: RoundedRectangle(cornerRadius: AppRadius.sm)
                    )

                // Inline comments
                ForEach(comments) { comment in
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        Image(systemName: "text.bubble.fill")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.metricWarm)
                        Text(comment.text)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.metricWarm)
                        Spacer()
                        Button { onRemoveComment(comment.id) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColors.neutral)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Spacing.xs)
                    .background(AppColors.tintedBackground(AppColors.metricWarm, opacity: 0.08), in: RoundedRectangle(cornerRadius: AppRadius.sm))
                }

                // Add comment button
                Button(action: onAddComment) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "plus.bubble")
                        Text(hasComments ? "Add Another" : "Add Comment")
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.primaryAction)
                    .padding(.vertical, Spacing.xxs)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .padding(.horizontal, Spacing.xs)
    }
}

// MARK: - Add Comment Sheet

private struct AddCommentSheet: View {
    let paragraphPreview: String
    let onSubmit: (String) -> Void
    @State private var text = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview of paragraph
                ScrollView {
                    Text(String(paragraphPreview.prefix(300)))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.neutral)
                        .lineLimit(6)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.neutral.opacity(0.06), in: RoundedRectangle(cornerRadius: AppRadius.sm))
                        .padding(Spacing.md)
                }
                .frame(maxHeight: 120)

                Spacer()

                // Input bar — pinned to bottom
                Divider()
                HStack(alignment: .center, spacing: Spacing.sm) {
                    // Microphone button (placeholder)
                    Button {} label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppColors.neutral)
                            .frame(width: 36, height: 36)
                    }

                    // Text input
                    TextField("What should change here\u{2026}", text: $text, axis: .vertical)
                        .font(AppTypography.body)
                        .lineLimit(1...8)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(AppColors.neutral.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                        .focused($isFocused)

                    // Send button
                    Button {
                        let trimmed = text.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSubmit(trimmed)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                text.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AppColors.neutral
                                    : AppColors.primaryAction
                            )
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .navigationTitle("Add Comment")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { isFocused = true }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
