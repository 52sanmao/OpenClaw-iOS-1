import SwiftUI

struct ControlCenterView: View {
    let sections: [ControlCenterSection]
    let isDragging: Bool
    let onDragHandlePress: () -> Void

    private var moduleCount: Int {
        sections.reduce(0) { $0 + $1.modules.count }
    }

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        CardContainer(
            title: "控制中心",
            systemImage: "square.grid.2x2.fill",
            isStale: false,
            isLoading: false
        ) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header

                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }

                HomeCardDetailHint()
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: ControlCenterSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: section.icon)
                    .font(AppTypography.nano)
                    .foregroundStyle(section.tint)
                Text(section.title)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(.primary)
                Text(section.subtitle)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(section.modules) { module in
                    NavigationLink {
                        module.destination
                    } label: {
                        ControlCenterTile(module: module)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("按用途分组的控制面板")
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("智能配置、自动化、连接、运维各自独立 — 点击卡片进入二级详情页。")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
            Spacer(minLength: Spacing.sm)
            Button(action: onDragHandlePress) {
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Image(systemName: isDragging ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.circle")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primaryAction)
                    Text("按住拖动")
                        .font(AppTypography.nano)
                        .foregroundStyle(AppColors.primaryAction)
                    Text("\(moduleCount) 个模块")
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColors.primaryAction)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.primaryAction.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.2)
                    .onEnded { _ in onDragHandlePress() }
            )
            .accessibilityLabel("长按拖动控制中心卡片")
        }
    }
}

struct ControlCenterSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let modules: [ControlCenterModule]
}

struct ControlCenterModule: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let detail: String
    let destination: AnyView
}

private struct ControlCenterTile: View {
    let module: ControlCenterModule

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(AppColors.tintedBackground(module.tint, opacity: 0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: module.icon)
                        .font(AppTypography.caption)
                        .foregroundStyle(module.tint)
                }
                Spacer(minLength: Spacing.xs)
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(module.tint.opacity(0.9))
            }

            HStack {
                Text(module.detail)
                    .font(AppTypography.nano)
                    .foregroundStyle(module.tint)
                    .padding(.horizontal, Spacing.xxs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AppColors.tintedBackground(module.tint, opacity: 0.12))
                    )
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(module.title)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(.primary)
                Text(module.subtitle)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(2)
            }

            HStack(spacing: Spacing.xxs) {
                Text("进入")
                    .font(AppTypography.nano)
                Image(systemName: "arrow.up.right")
                    .font(AppTypography.nano)
            }
            .foregroundStyle(module.tint)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .strokeBorder(AppColors.tintedBackground(module.tint, opacity: 0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(module.title)，\(module.subtitle)，\(module.detail)")
    }
}
