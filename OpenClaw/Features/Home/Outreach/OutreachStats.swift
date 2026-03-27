import Foundation

struct OutreachStats: Sendable {
    let totalLeads: Int
    let newLeads: Int
    let emailSent: Int
    let waSent: Int
    let replied: Int
    let converted: Int
    let replyRatePct: Double
    let timestamp: Date

    init(dto: OutreachStatsDTO) {
        totalLeads = dto.totalLeads
        newLeads = dto.newLeads
        emailSent = dto.emailSent
        waSent = dto.waSent
        replied = dto.replied
        converted = dto.converted
        replyRatePct = dto.replyRatePct
        timestamp = Date(timeIntervalSince1970: Double(dto.timestamp))
    }
}
