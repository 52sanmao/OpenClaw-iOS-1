import Foundation

struct BlogStatsDTO: Decodable, Sendable {
    let published: Int
    let queued: Int
    let researching: Int
    let writing: Int
    let generatingImages: Int
    let publishing: Int
    let lastPublishedTitle: String?
    let lastPublishedSlug: String?
    let lastPublishedUrl: String?
    let timestamp: Int
}
