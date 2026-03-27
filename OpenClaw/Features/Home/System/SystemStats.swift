import Foundation

struct SystemStats: Sendable {
    let cpuPercent: Double
    let ramUsedMb: Int
    let ramTotalMb: Int
    let ramPercent: Double
    let diskUsedMb: Int
    let diskTotalMb: Int
    let diskPercent: Double
    let loadAvg1M: Double
    let loadAvg5M: Double
    let uptimeSeconds: Double
    let timestamp: Date

    var uptimeFormatted: String {
        let total = Int(uptimeSeconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    init(dto: SystemStatsDTO) {
        cpuPercent = dto.cpuPercent
        ramUsedMb = dto.ramUsedMb
        ramTotalMb = dto.ramTotalMb
        ramPercent = dto.ramPercent
        diskUsedMb = dto.diskUsedMb
        diskTotalMb = dto.diskTotalMb
        diskPercent = dto.diskPercent
        loadAvg1M = dto.loadAvg1M
        loadAvg5M = dto.loadAvg5M
        uptimeSeconds = dto.uptimeSeconds
        timestamp = Date(timeIntervalSince1970: Double(dto.timestamp))
    }
}
