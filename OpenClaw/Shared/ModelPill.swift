import SwiftUI

/// Reusable model name pill (capsule badge) with provider icon.
/// Used across cron runs, investigations, trace views, token usage, admin.
struct ModelPill: View {
    let model: String

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ProviderIcon(model: model, size: 12)
            Text(Formatters.modelShortName(model))
                .font(AppTypography.micro)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
        .background(AppColors.pillBackground, in: Capsule())
        .foregroundStyle(AppColors.pillForeground)
    }
}
