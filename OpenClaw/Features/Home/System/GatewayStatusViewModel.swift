import Foundation
import Observation

/// Polls /api/gateway/status — the real IronClaw Web API endpoint.
/// Replaces the old SystemHealthViewModel which targeted the non-existent /stats/sys route.
@Observable
@MainActor
final class GatewayStatusViewModel {
    var status: GatewayRichStatusDTO?
    var isLoading = false
    var error: Error?
    var lastUpdated: Date?

    private let client: GatewayClientProtocol
    private var pollTask: Task<Void, Never>?

    init(client: GatewayClientProtocol) {
        self.client = client
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            status = try await client.stats("api/gateway/status")
            lastUpdated = Date()
            error = nil
        } catch {
            self.error = error
            AppLogStore.shared.append("GatewayStatusViewModel: refresh 失败 \(error.localizedDescription)")
        }
    }

    func startPolling(interval: TimeInterval = 15) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
