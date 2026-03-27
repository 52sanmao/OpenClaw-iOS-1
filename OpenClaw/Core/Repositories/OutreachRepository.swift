import Foundation

protocol OutreachRepository: Sendable {
    func fetch() async throws -> OutreachStats
}

final class RemoteOutreachRepository: OutreachRepository {
    private let client: GatewayClientProtocol
    private let cache = MemoryCache<OutreachStats>(ttl: 60)

    init(client: GatewayClientProtocol) {
        self.client = client
    }

    func fetch() async throws -> OutreachStats {
        if let cached = await cache.get() { return cached }
        let dto: OutreachStatsDTO = try await client.stats("stats/outreach")
        let model = OutreachStats(dto: dto)
        await cache.set(model)
        return model
    }
}
