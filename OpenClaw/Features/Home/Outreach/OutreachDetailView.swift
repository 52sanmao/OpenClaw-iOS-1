import SwiftUI

struct OutreachDetailView: View {
    let vm: OutreachStatsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                if let stats = vm.data {
                    VStack(spacing: Spacing.md) {
                        if vm.isStale {
                            HomeStaleNotice()
                        }

                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(stats.totalLeads)")
                                    .font(AppTypography.heroNumber)
                                Text("潜在线索总数")
                                    .font(AppTypography.micro)
                                    .foregroundStyle(AppColors.neutral)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f%%", stats.replyRatePct))
                                    .font(AppTypography.metricValue)
                                    .foregroundStyle(AppColors.metricHighlight)
                                Text("回复率")
                                    .font(AppTypography.micro)
                                    .foregroundStyle(AppColors.neutral)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("潜在线索总数 \(stats.totalLeads)，回复率 \(String(format: "%.1f", stats.replyRatePct))%")

                        HomeDetailSection("推进情况") {
                            HomeDetailRow(title: "新增线索", value: "\(stats.newLeads)")
                            HomeDetailRow(title: "已发邮件", value: "\(stats.emailSent)")
                            HomeDetailRow(title: "WhatsApp", value: "\(stats.waSent)")
                            HomeDetailRow(title: "已回复", value: "\(stats.replied)")
                            HomeDetailRow(title: "已转化", value: "\(stats.converted)")
                        }

                        HomeDetailSection("更新时间") {
                            HomeDetailRow(title: "最近同步", value: Formatters.absoluteString(for: stats.timestamp))
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
                DetailTitleView(title: "外联") {
                    Text(vm.isStale ? "缓存数据" : "最新统计")
                        .font(AppTypography.micro)
                        .foregroundStyle(vm.isStale ? AppColors.warning : AppColors.success)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("刷新外联统计")
            }
        }
    }
}
