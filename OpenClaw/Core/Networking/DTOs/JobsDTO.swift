import Foundation

// MARK: - /api/jobs  — async job list

struct JobsResponseDTO: Decodable, Sendable {
    let jobs: [JobDTO]
}

struct JobDTO: Decodable, Sendable, Identifiable {
    let id: String
    let title: String?
    let state: String?         // pending | in_progress | completed | failed | stuck
    let userId: String?
    let createdAt: String?
    let startedAt: String?
}

// MARK: - /api/jobs/summary

struct JobsSummaryDTO: Decodable, Sendable {
    let total: Int
    let pending: Int
    let inProgress: Int
    let completed: Int
    let failed: Int
    let stuck: Int
}

// MARK: - /api/jobs/{id}

struct JobDetailDTO: Decodable, Sendable {
    let id: String
    let title: String?
    let state: String?
    let userId: String?
    let createdAt: String?
    let startedAt: String?
    let finishedAt: String?
    let prompt: String?
    let result: String?
    let error: String?
}

// MARK: - /api/gateway/status (rich system status)

struct GatewayRichStatusDTO: Decodable, Sendable {
    let version: String?
    let sseConnections: Int?
    let wsConnections: Int?
    let totalConnections: Int?
    let uptimeSecs: Int?
    let restartEnabled: Bool?
    let dailyCost: String?
    let actionsThisHour: Int?
    let modelUsage: [ModelUsageDTO]?
    let llmBackend: String?
    let llmModel: String?
    let enabledChannels: [String]?

    struct ModelUsageDTO: Decodable, Sendable {
        let model: String
        let inputTokens: Int?
        let outputTokens: Int?
        let cost: String?
    }
}

// MARK: - /api/routines/summary

struct RoutinesSummaryDTO: Decodable, Sendable {
    let total: Int
    let enabled: Int
    let disabled: Int
    let unverified: Int
    let failing: Int
    let runsToday: Int
}

// MARK: - /api/logs/level

struct LogLevelDTO: Decodable, Sendable {
    let level: String
}
