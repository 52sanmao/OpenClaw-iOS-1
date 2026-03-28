import SwiftUI

/// 24-hour timeline showing when cron jobs are scheduled to run today.
struct ScheduleTimelineView: View {
    let jobs: [CronJob]
    private let hours = Array(0...23)

    private var jobColors: [String: Color] {
        let palette: [Color] = [
            AppColors.metricPrimary, AppColors.metricPositive, AppColors.metricTertiary,
            AppColors.metricWarm, AppColors.metricHighlight, AppColors.danger,
            AppColors.info, AppColors.metricSecondary, AppColors.success,
            .pink, .mint, .cyan
        ]
        var map: [String: Color] = [:]
        for (i, job) in enabledJobs.enumerated() {
            map[job.id] = palette[i % palette.count]
        }
        return map
    }

    private var enabledJobs: [CronJob] {
        jobs.filter(\.enabled)
    }

    private var scheduleByHour: [Int: [(job: CronJob, minute: Int)]] {
        let cal = Calendar.current
        let today = Date()
        var result: [Int: [(job: CronJob, minute: Int)]] = [:]
        for job in enabledJobs {
            for time in job.scheduledTimes(for: today) {
                let h = cal.component(.hour, from: time)
                let m = cal.component(.minute, from: time)
                result[h, default: []].append((job: job, minute: m))
            }
        }
        return result
    }

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    var body: some View {
        List {
            // Legend
            Section("Jobs") {
                FlowLayout(spacing: Spacing.xs) {
                    ForEach(enabledJobs) { job in
                        HStack(spacing: Spacing.xxs) {
                            Circle()
                                .fill(jobColors[job.id] ?? AppColors.neutral)
                                .frame(width: 8, height: 8)
                            Text(job.name)
                                .font(AppTypography.micro)
                        }
                    }
                }
            }

            // Timeline
            Section("Today's Schedule") {
                ForEach(hours, id: \.self) { hour in
                    HourRow(
                        hour: hour,
                        entries: scheduleByHour[hour] ?? [],
                        jobColors: jobColors,
                        isCurrent: hour == currentHour
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Hour Row

private struct HourRow: View {
    let hour: Int
    let entries: [(job: CronJob, minute: Int)]
    let jobColors: [String: Color]
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Hour label
            Text(String(format: "%02d:00", hour))
                .font(AppTypography.captionMono)
                .foregroundStyle(isCurrent ? AppColors.primaryAction : AppColors.neutral)
                .frame(width: 44, alignment: .leading)

            if isCurrent {
                Rectangle()
                    .fill(AppColors.danger)
                    .frame(width: 2, height: entries.isEmpty ? 20 : CGFloat(entries.count) * 22)
            }

            // Job dots
            if entries.isEmpty {
                Text("\u{2014}")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.neutral.opacity(0.3))
            } else {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    ForEach(entries.sorted(by: { $0.minute < $1.minute }), id: \.job.id) { entry in
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(jobColors[entry.job.id] ?? AppColors.neutral)
                                .frame(width: 8, height: 8)
                            Text(entry.job.name)
                                .font(AppTypography.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: ":%02d", entry.minute))
                                .font(AppTypography.captionMono)
                                .foregroundStyle(AppColors.neutral)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xxs)
        .background(isCurrent ? AppColors.primaryAction.opacity(0.04) : .clear)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Flow Layout (for legend)

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (offsets: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (offsets, CGSize(width: maxX, height: y + rowHeight))
    }
}
