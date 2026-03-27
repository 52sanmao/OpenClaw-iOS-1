import Foundation

@MainActor
final class CronSummaryViewModel: LoadableViewModel<[CronJob]> {
    init(repository: CronRepository) {
        super.init { try await repository.fetchJobs() }
    }
}
