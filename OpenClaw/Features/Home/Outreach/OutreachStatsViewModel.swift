import Foundation

@MainActor
final class OutreachStatsViewModel: LoadableViewModel<OutreachStats> {
    init(repository: OutreachRepository) {
        super.init { try await repository.fetch() }
    }
}
