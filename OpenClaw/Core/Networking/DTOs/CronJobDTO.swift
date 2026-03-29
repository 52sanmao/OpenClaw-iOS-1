import Foundation

struct CronJobListResponseDTO: Decodable, Sendable {
    let jobs: [CronJobDTO]
    let total: Int
}

struct CronJobDTO: Decodable, Sendable {
    let id: String
    let name: String
    let enabled: Bool
    let schedule: Schedule
    let state: State
    let payload: Payload?

    struct Payload: Decodable, Sendable {
        let model: String?
        let message: String?
    }

    struct Schedule: Decodable, Sendable {
        let kind: String
        let expr: String?
        let tz: String?
        let everyMs: Int?
    }

    struct State: Decodable, Sendable {
        let nextRunAtMs: Int?
        let lastRunAtMs: Int?
        let lastRunStatus: String?
        let consecutiveErrors: Int?
        let lastError: String?
    }
}
