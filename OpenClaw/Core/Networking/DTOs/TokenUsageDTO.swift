import Foundation

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
