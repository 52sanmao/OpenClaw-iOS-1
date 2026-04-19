import Foundation
import Observation

@Observable
@MainActor
final class PipelineTokenViewModel {
    var breakdown: PipelineBreakdown?
    var isLoading = false
    var error: Error?

    private let repository: CronDetailRepository
    private static let runsPerJob = 100

    init(repository: CronDetailRepository) {
        self.repository = repository
    }

    func load(period: TokenPeriod, totalTokens: Int) async {
        isLoading = true
        error = nil

        let range = period.range(reference: Date(), calendar: .current)

        do {
            let results = try await withThrowingTaskGroup(of: (String, Int, Int).self) { group in
                for pipeline in PipelineUsage.pipelines {
                    for jobId in pipeline.jobIds {
                        group.addTask {
                            let page = try await self.repository.fetchRuns(
                                jobId: jobId,
                                limit: Self.runsPerJob,
                                offset: 0
                            )
                            let filtered = page.runs.filter { range.contains($0.runAt) }
                            let tokens = filtered.reduce(0) { $0 + $1.totalTokens }
                            return (jobId, tokens, filtered.count)
                        }
                    }
                }

                var map: [String: (tokens: Int, runs: Int)] = [:]
                for try await (jobId, tokens, runs) in group {
                    map[jobId] = (tokens, runs)
                }
                return map
            }

            // Aggregate per pipeline
            var pipelineTokenSum = 0
            var pipelines: [PipelineUsage] = []

            for pipeline in PipelineUsage.pipelines {
                let tokens = pipeline.jobIds.reduce(0) { $0 + (results[$1]?.tokens ?? 0) }
                let runs = pipeline.jobIds.reduce(0) { $0 + (results[$1]?.runs ?? 0) }
                guard tokens > 0 else { continue }

                pipelineTokenSum += tokens
                pipelines.append(PipelineUsage(
                    id: pipeline.name,
                    name: pipeline.name,
                    totalTokens: tokens,
                    runCount: runs
                ))
            }

            pipelines.sort { $0.totalTokens > $1.totalTokens }

            let mainTokens = max(totalTokens - pipelineTokenSum, 0)
            let mainSession = PipelineUsage(
                id: "main-session",
                name: "主会话",
                totalTokens: mainTokens,
                runCount: 0
            )

            breakdown = PipelineBreakdown(pipelines: pipelines, mainSession: mainSession)
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
