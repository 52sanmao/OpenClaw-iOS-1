import SwiftUI

struct PairingSheetState: Identifiable {
    let channelId: String
    let channelName: String
    let response: PairingResponseDTO?
    let error: String?
    var id: String { channelId }
}

struct PairingSheet: View {
    let state: PairingSheetState
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("频道") {
                    LabeledContent("名称", value: state.channelName)
                    LabeledContent("ID", value: state.channelId)
                }

                if let err = state.error {
                    Section("加载失败") {
                        Text(err)
                            .foregroundStyle(AppColors.danger)
                            .textSelection(.enabled)
                    }
                } else if let resp = state.response {
                    requestsSection(resp.requests ?? [])
                }
            }
            .navigationTitle("频道配对")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭", action: onClose)
                }
            }
        }
    }

    @ViewBuilder
    private func requestsSection(_ requests: [PairingRequestDTO]) -> some View {
        Section {
            if requests.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AppColors.success)
                    Text("没有待处理的配对请求，频道已就绪。")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.neutral)
                }
            } else {
                ForEach(Array(requests.enumerated()), id: \.offset) { _, req in
                    row(req)
                }
            }
        } header: {
            Text("待处理配对请求")
        } footer: {
            Text("当外部用户（如 Telegram 账户）发起配对时，请求会出现在这里。")
        }
    }

    @ViewBuilder
    private func row(_ req: PairingRequestDTO) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                if let id = req.id {
                    Text(id)
                        .font(AppTypography.captionMono)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if let status = req.status {
                    Text(status.capitalized)
                        .font(AppTypography.nano)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.warning.opacity(0.14)))
                        .foregroundStyle(AppColors.warning)
                }
            }
            if let uid = req.userId, !uid.isEmpty {
                Text("user: \(uid)")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
            if let t = req.createdAt {
                Text(t)
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
        }
    }
}
