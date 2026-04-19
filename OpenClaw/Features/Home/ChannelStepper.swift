import SwiftUI

/// 频道 onboarding 3 步进度条：配置凭据 → 配对/激活 → 已就绪。
/// 对齐 Web UI 中 `renderWasmChannelStepper()`：每个 step 有
/// completed / in-progress / failed / pending 四种态。
struct ChannelStepper: View {
    /// `onboarding_state` 或 `activation_status` 的原始值。
    let status: String
    /// `onboarding.requires_pairing` — 影响第二步的文案。
    let requiresPairing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                if idx > 0 {
                    Rectangle()
                        .fill(idx <= reachedIdx ? step.tint.opacity(0.6) : AppColors.neutral.opacity(0.18))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 11)
                }
                stepView(idx: idx, step: step)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var steps: [Step] {
        [
            Step(label: "配置", completedSymbol: "checkmark", tint: AppColors.info),
            Step(label: requiresPairing ? "配对" : "激活", completedSymbol: "checkmark", tint: AppColors.metricTertiary),
            Step(label: "就绪", completedSymbol: "bolt.fill", tint: AppColors.success)
        ]
    }

    private var reachedIdx: Int {
        switch status.lowercased() {
        case "active", "ready":
            return 2
        case "pairing", "pairing_required":
            return 1
        case "failed":
            return 2
        case "configured", "activation_in_progress":
            return 1
        default:
            return 0
        }
    }

    private enum State {
        case completed, inProgress, failed, pending
    }

    private func state(for idx: Int) -> State {
        let s = status.lowercased()
        if s == "failed" && idx == reachedIdx { return .failed }
        if idx < reachedIdx { return .completed }
        if idx == reachedIdx {
            switch s {
            case "pairing", "pairing_required", "activation_in_progress", "setup_required":
                return .inProgress
            case "active", "ready", "configured", "installed":
                return .completed
            default: return .pending
            }
        }
        return .pending
    }

    @ViewBuilder
    private func stepView(idx: Int, step: Step) -> some View {
        let state = self.state(for: idx)
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(circleFill(state: state, tint: step.tint))
                    .frame(width: 24, height: 24)
                if state == .completed {
                    Image(systemName: step.completedSymbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else if state == .failed {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else if state == .inProgress {
                    Circle()
                        .fill(step.tint)
                        .frame(width: 10, height: 10)
                }
            }
            Text(step.label)
                .font(AppTypography.nano)
                .foregroundStyle(labelColor(state: state, tint: step.tint))
                .lineLimit(1)
        }
    }

    private func circleFill(state: State, tint: Color) -> Color {
        switch state {
        case .completed: return tint
        case .inProgress: return tint.opacity(0.14)
        case .failed: return AppColors.danger
        case .pending: return AppColors.neutral.opacity(0.12)
        }
    }

    private func labelColor(state: State, tint: Color) -> Color {
        switch state {
        case .completed: return tint
        case .inProgress: return tint
        case .failed: return AppColors.danger
        case .pending: return AppColors.neutral
        }
    }

    private struct Step {
        let label: String
        let completedSymbol: String
        let tint: Color
    }
}
