import Foundation
import Observation

/// System health VM with auto-polling every 15 seconds.
/// Polling starts when the view appears and stops when it disappears.
@Observable
@MainActor
final class SystemHealthViewModel {
    var data: SystemStats?
    var isLoading = false
    var error: Error?

    var isStale: Bool { error != nil && data != nil }

    private let repository: SystemHealthRepository
    private var pollTask: Task<Void, Never>?
    private static let pollInterval: TimeInterval = 15

    init(repository: SystemHealthRepository) {
        self.repository = repository
    }

    /// Call from `.task { }` — starts initial fetch + polling loop.
    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task {
            await fetch()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollInterval))
                guard !Task.isCancelled else { break }
                await fetch()
            }
        }
    }

    /// Call when view disappears — stops the polling loop.
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Manual refresh (pull-to-refresh).
    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        if data == nil { isLoading = true }
        do {
            let result = try await repository.fetch()
            guard !Task.isCancelled else { return }
            data = result
            error = nil
        } catch is CancellationError {
            // Silently ignore
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error
        }
        isLoading = false
    }
}
