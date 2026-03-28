import Foundation

struct PipelineUsage: Sendable, Identifiable {
    let id: String
    let name: String
    let totalTokens: Int
    let runCount: Int

    /// Known pipeline groups. Blog jobs are grouped into one pipeline.
    static let pipelines: [Pipeline] = [
        Pipeline(name: "Blog Pipeline", jobIds: ["a8f5aefc", "60d87107", "6d684c66", "80b36ebf"]),
        Pipeline(name: "Site Agent", jobIds: ["1cdf81d0"]),
        Pipeline(name: "Outreach Researcher", jobIds: ["4f46a1a5"]),
        Pipeline(name: "Outreach Email", jobIds: ["0bd91d74"]),
        Pipeline(name: "Reddit Engage", jobIds: ["fdf64f44"]),
        Pipeline(name: "Bluesky Engage", jobIds: ["95d4c914"]),
        Pipeline(name: "Server Watchdog", jobIds: ["d2a9e071"]),
    ]

    struct Pipeline: Sendable {
        let name: String
        let jobIds: [String]
    }
}

struct PipelineBreakdown: Sendable {
    let pipelines: [PipelineUsage]
    let mainSession: PipelineUsage
}
