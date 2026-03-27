import Foundation

protocol BlogRepository: Sendable {
    func fetch() async throws -> BlogStats
}

final class RemoteBlogRepository: BlogRepository {
    private let client: GatewayClientProtocol
    private let cache = MemoryCache<BlogStats>(ttl: 60)

    init(client: GatewayClientProtocol) {
        self.client = client
    }

    func fetch() async throws -> BlogStats {
        if let cached = await cache.get() { return cached }
        let dto: BlogStatsDTO = try await client.stats("stats/blog")
        let model = BlogStats(dto: dto)
        await cache.set(model)
        return model
    }
}
