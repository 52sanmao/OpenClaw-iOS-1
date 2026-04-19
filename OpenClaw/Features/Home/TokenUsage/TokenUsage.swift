import Foundation

enum TokenPeriod: String, CaseIterable, Identifiable {
    case today, yesterday, week

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:     "今天"
        case .yesterday: "昨天"
        case .week:      "最近 7 天"
        }
    }

    var bucketCount: Int {
        switch self {
        case .today, .yesterday: 24
        case .week: 7
        }
    }

    func bucketStartDates(reference: Date = Date(), calendar: Calendar = .current) -> [Date] {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: reference)
            return (0..<24).compactMap { calendar.date(byAdding: .hour, value: $0, to: start) }
        case .yesterday:
            let todayStart = calendar.startOfDay(for: reference)
            let start = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            return (0..<24).compactMap { calendar.date(byAdding: .hour, value: $0, to: start) }
        case .week:
            let todayStart = calendar.startOfDay(for: reference)
            let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }
    }

    func range(reference: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .today:
            let start = calendar.startOfDay(for: reference)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? reference
            return DateInterval(start: start, end: end)
        case .yesterday:
            let end = calendar.startOfDay(for: reference)
            let start = calendar.date(byAdding: .day, value: -1, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .week:
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference)) ?? reference
            let start = calendar.date(byAdding: .day, value: -7, to: end) ?? reference
            return DateInterval(start: start, end: end)
        }
    }

    func bucketStart(for date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .today, .yesterday:
            let comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: comps) ?? date
        case .week:
            return calendar.startOfDay(for: date)
        }
    }

    func bucketLabel(for date: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .today, .yesterday:
            return Self.hourFormatter.string(from: date)
        case .week:
            return Self.dayFormatter.string(from: date)
        }
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

struct TokenUsage: Sendable {
    let period: String
    let totals: Totals
    let byModel: [ModelUsage]
    let timeline: [TimelineBucket]

    struct Totals: Sendable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int
        let cacheWriteTokens: Int
        let totalTokens: Int
        let requestCount: Int
        let thinkingRequests: Int
        let toolRequests: Int
        let costUsd: Double

        var cacheHitRate: Double {
            Self.computeCacheHitRate(input: inputTokens, cacheRead: cacheReadTokens)
        }

        static func computeCacheHitRate(input: Int, cacheRead: Int) -> Double {
            let total = Double(input + cacheRead)
            guard total > 0 else { return 0 }
            return Double(cacheRead) / total
        }
    }

    struct ModelUsage: Sendable, Identifiable {
        var id: String { "\(model)-\(provider)" }
        let model: String
        let provider: String

        /// Full model string with provider prefix for display (e.g. "anthropic/claude-sonnet-4-6").
        var fullModel: String { "\(provider)/\(model)" }
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int
        let cacheWriteTokens: Int
        let totalTokens: Int
        let requestCount: Int
        let thinkingRequests: Int
        let toolRequests: Int
        let costUsd: Double

        var cacheHitRate: Double {
            Totals.computeCacheHitRate(input: inputTokens, cacheRead: cacheReadTokens)
        }
    }

    struct TimelineBucket: Sendable, Identifiable {
        let startDate: Date
        let totalTokens: Int
        let costUsd: Double
        let label: String

        var id: TimeInterval { startDate.timeIntervalSince1970 }
    }

    init(dto: TokenUsageDTO, timeline: [TimelineBucket] = []) {
        period = dto.period
        totals = Totals(
            inputTokens: dto.totals.inputTokens,
            outputTokens: dto.totals.outputTokens,
            cacheReadTokens: dto.totals.cacheReadTokens,
            cacheWriteTokens: dto.totals.cacheWriteTokens,
            totalTokens: dto.totals.totalTokens,
            requestCount: dto.totals.requestCount,
            thinkingRequests: dto.totals.thinkingRequests,
            toolRequests: dto.totals.toolRequests,
            costUsd: dto.totals.costUsd
        )
        byModel = dto.byModel
            .filter { $0.provider != "openclaw" }
            .map { ModelUsage(
                model: $0.model,
                provider: $0.provider,
                inputTokens: $0.inputTokens,
                outputTokens: $0.outputTokens,
                cacheReadTokens: $0.cacheReadTokens,
                cacheWriteTokens: $0.cacheWriteTokens,
                totalTokens: $0.totalTokens,
                requestCount: $0.requestCount,
                thinkingRequests: $0.thinkingRequests,
                toolRequests: $0.toolRequests,
                costUsd: $0.costUsd
            )}
        self.timeline = timeline.sorted { $0.startDate < $1.startDate }
    }
}
