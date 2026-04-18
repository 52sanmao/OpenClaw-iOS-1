import SwiftUI

struct HomeDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(AppTypography.cardTitle)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: Spacing.xs) {
                content
            }
        }
    }
}

struct HomeDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.neutral)

            Spacer()

            Text(value)
                .font(AppTypography.captionBold)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(Color(.systemBackground))
        )
        .accessibilityElement(children: .combine)
    }
}

struct HomeCardDetailHint: View {
    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Text("查看详情")
                .font(AppTypography.caption)
            Image(systemName: "chevron.right")
                .font(AppTypography.micro)
        }
        .foregroundStyle(AppColors.primaryAction)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("查看详情")
    }
}

struct HomeStaleNotice: View {
    let text: String

    init(text: String = "当前展示的是最近一次成功获取的数据，可下拉或点右上角刷新。") {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.warning)
            Text(text)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.neutral)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColors.tintedBackground(AppColors.warning, opacity: 0.08))
        )
        .accessibilityElement(children: .combine)
    }
}
