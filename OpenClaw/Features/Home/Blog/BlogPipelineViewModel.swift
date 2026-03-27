import Foundation

@MainActor
final class BlogPipelineViewModel: LoadableViewModel<BlogStats> {
    init(repository: BlogRepository) {
        super.init { try await repository.fetch() }
    }
}
