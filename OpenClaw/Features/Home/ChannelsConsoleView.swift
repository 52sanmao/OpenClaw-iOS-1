import SwiftUI

/// 频道控制台 — 频道连接矩阵 + 提供商配额环形仪表。
struct ChannelsConsoleView: View {
    let adminVM: AdminViewModel

    private let matrixColumns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if let status = adminVM.channelsStatus {
                    connectionMatrix(status)
                    providerPanels(status)
                } else if adminVM.isLoading {
                    CardLoadingView(minHeight: 180)
                } else if let error = adminVM.error {
                    CardErrorView(error: error, minHeight: 140)
                } else {
                    ContentUnavailableView(
                        "暂无频道数据",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("检查网关的 channels-list 扩展接口。")
                    )
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "频道") {
                    Text(subtitle)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }
            }
        }
        .refreshable {
            await adminVM.load()
            Haptics.shared.refreshComplete()
        }
    }

    private var subtitle: String {
        guard let status = adminVM.channelsStatus else { return "连接与配额" }
        let connected = status.channels.filter { $0.isConnected }.count
        let total = status.channels.count
        return "\(connected)/\(total) 已连接 · \(status.providers.count) 个提供商"
    }

    // MARK: - Connection matrix

    @ViewBuilder
    private func connectionMatrix(_ status: ChannelsStatus) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(AppColors.success)
                Text("频道连接")
                    .font(AppTypography.captionBold)
                Spacer()
                Text("\(status.channels.filter { $0.isConnected }.count)/\(status.channels.count) 已连接")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }

            LazyVGrid(columns: matrixColumns, spacing: Spacing.sm) {
                ForEach(status.channels) { channel in
                    channelTile(channel)
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
    private func channelTile(_ channel: ChannelsStatus.Channel) -> some View {
        let tint: Color = channel.isConnected ? AppColors.success : AppColors.neutral
        VStack(spacing: Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(tint.opacity(channel.isConnected ? 0.14 : 0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: channelIcon(channel.id))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                if channel.isConnected {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .offset(x: 14, y: -14)
                }
            }
            Text(channel.name)
                .font(AppTypography.captionBold)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if channel.isConnected {
                Text("\(channel.accountCount) 账号")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            } else {
                Text("未连接")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.tintedBackground(tint, opacity: channel.isConnected ? 0.06 : 0.03))
        )
    }

    private func channelIcon(_ id: String) -> String {
        switch id.lowercased() {
        case "telegram":   return "paperplane.fill"
        case "whatsapp":   return "phone.circle.fill"
        case "webchat":    return "globe"
        case "discord":    return "gamecontroller.fill"
        case "slack":      return "number"
        default:           return "bubble.left.and.bubble.right.fill"
        }
    }

    // MARK: - Provider panels

    @ViewBuilder
    private func providerPanels(_ status: ChannelsStatus) -> some View {
        if status.providers.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "gauge.medium")
                        .foregroundStyle(AppColors.metricPrimary)
                    Text("提供商配额")
                        .font(AppTypography.captionBold)
                    Spacer()
                    Text("\(status.providers.count) 个")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.neutral)
                }

                VStack(spacing: Spacing.sm) {
                    ForEach(status.providers) { provider in
                        providerCard(provider)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func providerCard(_ provider: ChannelsStatus.ProviderUsage) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                ProviderIcon(provider: provider.id, size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.displayName)
                        .font(AppTypography.body)
                        .fontWeight(.medium)
                    if let plan = provider.plan {
                        Text(plan)
                            .font(AppTypography.nano)
                            .foregroundStyle(AppColors.neutral)
                    }
                }
                Spacer()
                Text("\(provider.windows.count) 窗口")
                    .font(AppTypography.nano)
                    .foregroundStyle(AppColors.neutral)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.neutral.opacity(0.08)))
            }

            if provider.windows.isEmpty {
                Text("未开放配额窗口")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        ForEach(provider.windows) { window in
                            RingGauge(
                                value: min(window.usedPercent / 100, 1),
                                label: window.label,
                                color: AppColors.gauge(percent: window.usedPercent, warn: 70, critical: 90)
                            )
                        }
                    }
                    .padding(.vertical, Spacing.xxs)
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
}
