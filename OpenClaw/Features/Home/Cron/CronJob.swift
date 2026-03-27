import Foundation

struct CronJob: Sendable, Identifiable {
    let id: String
    let name: String
    let enabled: Bool
    let scheduleExpr: String
    let scheduleKind: String
    let timeZone: String?
    let nextRun: Date?
    let lastRun: Date?
    let status: RunStatus
    let consecutiveErrors: Int

    enum RunStatus: Sendable {
        case succeeded, failed, unknown, never
    }

    var nextRunFormatted: String {
        guard let nextRun else { return "\u{2014}" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: nextRun, relativeTo: Date())
    }

    init(dto: CronJobDTO) {
        id = dto.id
        name = dto.name
        enabled = dto.enabled
        scheduleExpr = dto.schedule.expr
        scheduleKind = dto.schedule.kind
        timeZone = dto.schedule.tz
        nextRun = dto.state.nextRunAtMs.map { Date(timeIntervalSince1970: Double($0) / 1000) }
        lastRun = dto.state.lastRunAtMs.map { Date(timeIntervalSince1970: Double($0) / 1000) }
        consecutiveErrors = dto.state.consecutiveErrors ?? 0

        switch dto.state.lastRunStatus {
        case "ok":    status = .succeeded
        case "error": status = .failed
        case .some:   status = .unknown
        case nil:     status = .never
        }
    }
}
