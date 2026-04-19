import SwiftUI

/// 网关状态卡 — 替换旧的 SystemHealthCard。
/// 数据源：/api/gateway/status（version / uptime / connections / daily cost / enabled channels / llm_backend）。
struct GatewayStatusCard: View {
    @Bindable var vm: GatewayStatusViewModel

    var body: some View {
        CardContainer(
            title: "网关状态",
            systemImage: "shield.checkerboard",
            isStale: vm.status != nil && vm.error != nil,
            isLoading: vm.status == nil && vm.isLoading
        ) {
            if let s = vm.status {
                content(s)
            } else if vm.isLoading {
                CardLoadingView(minHeight: 90)
            } else if let err = vm.error {
                CardErrorView(error: err, minHeight: 90)
            } else {
                Text("等待 /api/gateway/status")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
    }

    @ViewBuilder
    private func content(_ s: GatewayRichStatusDTO) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header: version + uptime
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.success.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "server.rack")
                        .foregroundStyle(AppColors.success)
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xxs) {
                        Text("v" + (s.version ?? "-"))
                            .font(AppTypography.cardTitle)
                        Text("已运行")
                            .font(AppTypography.nano)
                            .foregroundStyle(AppColors.neutral)
                        Text(uptimeText(s.uptimeSecs ?? 0))
                            .font(AppTypography.captionMono)
                            .foregroundStyle(.primary)
                    }
                    if let backend = s.llmBackend, let model = s.llmModel {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "cpu")
                                .font(AppTypography.nano)
                                .foregroundStyle(AppColors.metricPrimary)
                            Text("\(backend) · \(model)")
                                .font(AppTypography.captionMono)
                                .foregroundStyle(AppColors.neutral)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                Spacer()
                Button {
                    Task { await vm.refresh() }
                    Haptics.shared.refreshComplete()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primaryAction)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("刷新网关状态")
            }

            // Stats grid
            HStack(spacing: Spacing.sm) {
                metricTile(
                    icon: "dot.radiowaves.left.and.right",
                    value: "\(s.totalConnections ?? 0)",
                    label: "连接",
                    tint: AppColors.info,
                    detail: "SSE \(s.sseConnections ?? 0) · WS \(s.wsConnections ?? 0)"
                )
                metricTile(
                    icon: "bolt.fill",
                    value: "\(s.actionsThisHour ?? 0)",
                    label: "本时操作",
                    tint: AppColors.metricPrimary,
                    detail: "滑动 1 小时窗"
                )
                metricTile(
                    icon: "dollarsign.circle.fill",
                    value: "$" + (s.dailyCost ?? "0.00"),
                    label: "今日费用",
                    tint: AppColors.metricWarm,
                    detail: "累计"
                )
            }

            if let channels = s.enabledChannels, !channels.isEmpty {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.success)
                    Text("启用频道")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.neutral)
                    ForEach(channels, id: \.self) { ch in
                        Text(ch.capitalized)
                            .font(AppTypography.nano)
                            .padding(.horizontal, Spacing.xxs)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(AppColors.success.opacity(0.10)))
                            .foregroundStyle(AppColors.success)
                    }
                    Spacer()
                }
            }

            HomeCardDetailHint()
        }
    }

    @ViewBuilder
    private func metricTile(icon: String, value: String, label: String, tint: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(AppTypography.nano)
                    .foregroundStyle(tint)
                Text(label)
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
            Text(value)
                .font(AppTypography.cardTitle)
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(detail)
                .font(AppTypography.nano)
                .foregroundStyle(AppColors.neutral)
                .lineLimit(1)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.tintedBackground(tint, opacity: 0.06))
        )
    }

    private func uptimeText(_ secs: Int) -> String {
        let days = secs / 86400
        let hours = (secs % 86400) / 3600
        let minutes = (secs % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
