import Foundation

enum TokenPeriod: String, CaseIterable, Identifiable {
    case today, yesterday, week

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:     "Today"
        case .yesterday: "Yesterday"
        case .week:      "7 Days"
        }
    }
}

struct TokenUsage: Sendable {
    let period: String
    let totals: Totals
    let byModel: [ModelUsage]

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

    init(dto: TokenUsageDTO) {
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
    }
}

// MARK: - DTO

struct TokenUsageDTO: Decodable, Sendable {
    let period: String
    let totals: TotalsDTO
    let byModel: [ModelUsageDTO]

    // No CodingKeys needed — stats() decoder uses .convertFromSnakeCase

    struct TotalsDTO: Decodable, Sendable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int
        let cacheWriteTokens: Int
        let totalTokens: Int
        let requestCount: Int
        let thinkingRequests: Int
        let toolRequests: Int
        let costUsd: Double
    }

    struct ModelUsageDTO: Decodable, Sendable {
        let model: String
        let provider: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadTokens: Int
        let cacheWriteTokens: Int
        let totalTokens: Int
        let requestCount: Int
        let thinkingRequests: Int
        let toolRequests: Int
        let costUsd: Double
    }
}
