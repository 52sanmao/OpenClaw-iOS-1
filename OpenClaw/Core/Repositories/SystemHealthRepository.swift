import Foundation

protocol SystemHealthRepository: Sendable {
    func fetch() async throws -> SystemStats
}

final class RemoteSystemHealthRepository: SystemHealthRepository {
    private let client: GatewayClientProtocol
    private let cache = MemoryCache<SystemStats>(ttl: 30)

    init(client: GatewayClientProtocol) {
        self.client = client
    }

    func fetch() async throws -> SystemStats {
        if let cached = await cache.get() { return cached }
        let dto: SystemStatsDTO = try await client.stats("stats/system")
        let model = SystemStats(dto: dto)
        await cache.set(model)
        return model
    }
}
