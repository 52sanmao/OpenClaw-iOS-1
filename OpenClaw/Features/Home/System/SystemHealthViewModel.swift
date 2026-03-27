import Foundation

@MainActor
final class SystemHealthViewModel: LoadableViewModel<SystemStats> {
    init(repository: SystemHealthRepository) {
        super.init { try await repository.fetch() }
    }
}
