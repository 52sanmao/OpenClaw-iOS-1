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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header

                VStack(alignment: .leading, spacing: Spacing.lg) {
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(section.tint.opacity(0.12))
                        .frame(width: 22, height: 22)
                    Image(systemName: section.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(section.tint)
                }
                Text(section.title)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(.primary)
                Text("·")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral.opacity(0.5))
                Text(section.subtitle)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text("\(section.modules.count)")
                    .font(AppTypography.nano)
                    .foregroundStyle(section.tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(section.tint.opacity(0.10)))
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
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(.primary)
                Text("\(moduleCount) 个模块 · 智能 / 自动化 / 连接 / 运维")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
            }
            Spacer(minLength: Spacing.sm)
            Button(action: onDragHandlePress) {
                HStack(spacing: 4) {
                    Image(systemName: isDragging ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.circle")
                        .font(AppTypography.caption)
                    Text(isDragging ? "拖动中" : "按住排序")
                        .font(AppTypography.nano)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(AppColors.primaryAction)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppColors.primaryAction.opacity(0.10)))
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
                        .fill(
                            LinearGradient(
                                colors: [
                                    module.tint.opacity(0.22),
                                    module.tint.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: module.icon)
                        .font(AppTypography.caption)
                        .foregroundStyle(module.tint)
                }
                Spacer(minLength: Spacing.xs)
                Image(systemName: "arrow.up.right")
                    .font(AppTypography.nano)
                    .foregroundStyle(module.tint.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(module.title)
                    .font(AppTypography.captionBold)
                    .foregroundStyle(.primary)
                Text(module.subtitle)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral)
                    .lineLimit(1)
            }

            HStack(spacing: Spacing.xxs) {
                Circle()
                    .fill(module.tint)
                    .frame(width: 6, height: 6)
                Text(module.detail)
                    .font(AppTypography.nano)
                    .foregroundStyle(module.tint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(Spacing.sm + Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .strokeBorder(AppColors.tintedBackground(module.tint, opacity: 0.22), lineWidth: 1)
        )
        .shadow(color: module.tint.opacity(0.08), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(module.title)，\(module.subtitle)，\(module.detail)")
    }
}
