import Foundation

struct BlogPipelineItem: Sendable {
    let label: String
    let count: Int
}

struct BlogStats: Sendable {
    let published: Int
    let queued: Int
    let researching: Int
    let writing: Int
    let generatingImages: Int
    let publishing: Int
    let lastPublishedTitle: String?
    let lastPublishedSlug: String?
    let lastPublishedUrl: URL?
    let timestamp: Date

    var activePipeline: [BlogPipelineItem] {
        [
            BlogPipelineItem(label: "Queued",      count: queued),
            BlogPipelineItem(label: "Researching", count: researching),
            BlogPipelineItem(label: "Writing",     count: writing),
            BlogPipelineItem(label: "Images",      count: generatingImages),
            BlogPipelineItem(label: "Publishing",  count: publishing),
        ].filter { $0.count > 0 }
    }

    init(dto: BlogStatsDTO) {
        published = dto.published
        queued = dto.queued
        researching = dto.researching
        writing = dto.writing
        generatingImages = dto.generatingImages
        publishing = dto.publishing
        lastPublishedTitle = dto.lastPublishedTitle
        lastPublishedSlug = dto.lastPublishedSlug
        lastPublishedUrl = dto.lastPublishedUrl.flatMap(URL.init(string:))
        timestamp = Date(timeIntervalSince1970: Double(dto.timestamp))
    }
}
