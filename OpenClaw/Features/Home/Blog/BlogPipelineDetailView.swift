import SwiftUI

struct BlogPipelineDetailView: View {
    let vm: BlogPipelineViewModel

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
                                Text("\(stats.published)")
                                    .font(AppTypography.heroNumber)
                                Text("已发布")
                                    .font(AppTypography.micro)
                                    .foregroundStyle(AppColors.neutral)
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("已发布 \(stats.published) 篇文章")

                        HomeDetailSection("流水线") {
                            HomeDetailRow(title: "待排队", value: "\(stats.queued)")
                            HomeDetailRow(title: "调研中", value: "\(stats.researching)")
                            HomeDetailRow(title: "撰写中", value: "\(stats.writing)")
                            HomeDetailRow(title: "生成配图", value: "\(stats.generatingImages)")
                            HomeDetailRow(title: "发布中", value: "\(stats.publishing)")
                        }

                        if let title = stats.lastPublishedTitle {
                            HomeDetailSection("最近发布") {
                                HomeDetailRow(title: "标题", value: title)
                                if let slug = stats.lastPublishedSlug {
                                    HomeDetailRow(title: "Slug", value: slug)
                                }
                                HomeDetailRow(title: "更新时间", value: Formatters.absoluteString(for: stats.timestamp))
                            }
                        }

                        if let url = stats.lastPublishedUrl {
                            Link(destination: url) {
                                HStack(spacing: Spacing.xs) {
                                    Text("打开最近发布文章")
                                        .font(AppTypography.captionBold)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(AppTypography.caption)
                                }
                                .foregroundStyle(AppColors.primaryAction)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: AppRadius.md)
                                        .fill(AppColors.tintedBackground(AppColors.metricPrimary, opacity: 0.08))
                                )
                            }
                            .accessibilityLabel("打开最近发布文章")
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
                DetailTitleView(title: "博客流水线") {
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
                .accessibilityLabel("刷新博客统计")
            }
        }
    }
}
