import Foundation

/// Simple in-memory cache with TTL. Thread-safe via actor isolation.
actor MemoryCache<T: Sendable> {
    private var value: T?
    private var cachedAt: Date?
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 60) {
        self.ttl = ttl
    }

    /// Returns cached value if still within TTL, otherwise nil.
    func get() -> T? {
        guard let value, let cachedAt, Date().timeIntervalSince(cachedAt) < ttl else {
            return nil
        }
        return value
    }

    /// Returns cached value regardless of TTL (for stale-while-revalidate).
    func getStale() -> T? {
        value
    }

    func set(_ newValue: T) {
        value = newValue
        cachedAt = Date()
    }

    func clear() {
        value = nil
        cachedAt = nil
    }
}
