import SwiftUI

struct SystemHealthDetailView: View {
    let vm: SystemHealthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if let stats = vm.data {
                    VStack(spacing: Spacing.md) {
                        if vm.isStale {
                            HomeStaleNotice()
                        }

                        HStack(spacing: Spacing.md) {
                            RingGauge(
                                value: stats.cpuPercent / 100,
                                label: "CPU",
                                color: AppColors.gauge(percent: stats.cpuPercent, warn: 60, critical: 80)
                            )
                            .frame(maxWidth: .infinity)

                            RingGauge(
                                value: stats.ramPercent / 100,
                                label: "RAM",
                                color: AppColors.gauge(percent: stats.ramPercent, warn: 70, critical: 85)
                            )
                            .frame(maxWidth: .infinity)

                            RingGauge(
                                value: stats.diskPercent / 100,
                                label: "磁盘",
                                color: AppColors.gauge(percent: stats.diskPercent, warn: 80, critical: 90)
                            )
                            .frame(maxWidth: .infinity)
                        }

                        HomeDetailSection("运行状态") {
                            HomeDetailRow(title: "运行时长", value: stats.uptimeFormatted)
                            HomeDetailRow(title: "1 分钟负载", value: String(format: "%.2f", stats.loadAvg1M))
                            HomeDetailRow(title: "5 分钟负载", value: String(format: "%.2f", stats.loadAvg5M))
                        }

                        HomeDetailSection("资源占用") {
                            HomeDetailRow(title: "内存", value: "\(stats.ramUsedMb) / \(stats.ramTotalMb) MB")
                            HomeDetailRow(title: "磁盘", value: "\(stats.diskUsedMb) / \(stats.diskTotalMb) MB")
                            HomeDetailRow(title: "刷新时间", value: Formatters.absoluteString(for: stats.timestamp))
                        }
                    }
                } else if vm.isLoading {
                    CardLoadingView(minHeight: 180)
                } else if let err = vm.error {
                    CardErrorView(error: err, minHeight: 120)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DetailTitleView(title: "系统健康") {
                    Text(vm.error == nil ? "运行中" : "有异常")
                        .font(AppTypography.micro)
                        .foregroundStyle(vm.error == nil ? AppColors.success : AppColors.warning)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("刷新健康状态")
            }
        }
    }
}
