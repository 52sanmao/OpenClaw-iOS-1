import SwiftUI
internal import Combine

/// Displays a live-updating elapsed time counter. Starts automatically on appear.
struct ElapsedTimer: View {
    @State private var elapsed: TimeInterval = 0
    @State private var startTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatted)
            .font(AppTypography.captionMono)
            .foregroundStyle(AppColors.neutral)
            .contentTransition(.numericText())
            .monospacedDigit()
            .onReceive(timer) { _ in
                elapsed = Date().timeIntervalSince(startTime)
            }
    }

    private var formatted: String {
        let seconds = Int(elapsed)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remaining = seconds % 60
        return "\(minutes)m \(String(format: "%02d", remaining))s"
    }
}
