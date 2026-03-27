import Foundation

struct SystemStatsDTO: Decodable, Sendable {
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
    let timestamp: Int
}
