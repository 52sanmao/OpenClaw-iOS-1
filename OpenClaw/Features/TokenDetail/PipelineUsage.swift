import Foundation

struct PipelineUsage: Sendable, Identifiable {
    let id: String
    let name: String
    let totalTokens: Int
    let runCount: Int

    /// Known pipeline groups. Blog jobs are grouped into one pipeline.
    static let pipelines: [Pipeline] = [
        Pipeline(name: "博客流水线", jobIds: ["a8f5aefc", "60d87107", "6d684c66", "80b36ebf"]),
        Pipeline(name: "站点代理", jobIds: ["1cdf81d0"]),
        Pipeline(name: "外联研究", jobIds: ["4f46a1a5"]),
        Pipeline(name: "外联邮件", jobIds: ["0bd91d74"]),
        Pipeline(name: "Reddit 互动", jobIds: ["fdf64f44"]),
        Pipeline(name: "Bluesky 互动", jobIds: ["95d4c914"]),
        Pipeline(name: "服务器看门狗", jobIds: ["d2a9e071"]),
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
