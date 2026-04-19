import Foundation
import Observation

@Observable
@MainActor
final class TokenUsageViewModel {
    private static let timelineSessionLimit = 400

    var data: TokenUsage?
    var isLoading = false
    var error: Error?
    var selectedPeriod: TokenPeriod = .today

    var isStale: Bool { error != nil && data != nil }

    private let client: GatewayClientProtocol

    init(client: GatewayClientProtocol) {
        self.client = client
    }

    func start() {
        Task { await load() }
    }

    func refresh() async {
        await load()
    }

    private func load() async {
        if data == nil { isLoading = true }
        do {
            let dto: TokenUsageDTO = try await client.stats("stats/tokens?period=\(selectedPeriod.rawValue)")
            let timeline = await loadTimeline(period: selectedPeriod, totals: dto.totals)
            data = TokenUsage(dto: dto, timeline: timeline)
            error = nil
        } catch let gatewayError as GatewayError {
            if case .httpError(404, _) = gatewayError {
                data = nil
                error = nil
            } else {
                error = gatewayError
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func loadTimeline(period: TokenPeriod, totals: TokenUsageDTO.TotalsDTO) async -> [TokenUsage.TimelineBucket] {
        let reference = Date()
        let calendar = Calendar.current
        let seeds = period.bucketStartDates(reference: reference, calendar: calendar)
        guard !seeds.isEmpty else { return [] }

        var rawTokens = Dictionary(uniqueKeysWithValues: seeds.map { ($0, 0) })
        var rawCosts = Dictionary(uniqueKeysWithValues: seeds.map { ($0, 0.0) })
        var bucketWeights = Dictionary(uniqueKeysWithValues: seeds.map { ($0, 0) })

        do {
            let response: SessionListResponseDTO = try await client.invoke(
                SessionListToolRequest(args: .init(limit: Self.timelineSessionLimit))
            )
            let range = period.range(reference: reference, calendar: calendar)

            for session in response.sessions {
                guard let timestamp = Self.timelineDate(for: session), range.contains(timestamp) else { continue }
                let bucketStart = period.bucketStart(for: timestamp, calendar: calendar)
                guard rawTokens[bucketStart] != nil else { continue }

                rawTokens[bucketStart, default: 0] += max(session.totalTokens ?? 0, 0)
                rawCosts[bucketStart, default: 0] += max(session.estimatedCostUsd ?? 0, 0)
                bucketWeights[bucketStart, default: 0] += 1
            }
        } catch {
            // Fall back to synthesized distribution below so totals still match /stats/tokens.
        }

        let tokenValues = scaledTokenValues(
            seeds: seeds,
            rawValues: rawTokens,
            fallbackWeights: bucketWeights,
            target: totals.totalTokens
        )
        let costValues = scaledCostValues(
            seeds: seeds,
            rawCosts: rawCosts,
            target: totals.costUsd,
            tokenValues: tokenValues,
            totalTokens: totals.totalTokens
        )

        return seeds.map { date in
            TokenUsage.TimelineBucket(
                startDate: date,
                totalTokens: tokenValues[date, default: 0],
                costUsd: costValues[date, default: 0],
                label: period.bucketLabel(for: date, calendar: calendar)
            )
        }
    }

    private func scaledTokenValues(
        seeds: [Date],
        rawValues: [Date: Int],
        fallbackWeights: [Date: Int],
        target: Int
    ) -> [Date: Int] {
        guard target > 0 else {
            return Dictionary(uniqueKeysWithValues: seeds.map { ($0, 0) })
        }

        let rawTotal = rawValues.values.reduce(0, +)
        let weightedSource: [Date: Double]

        if rawTotal > 0 {
            weightedSource = Dictionary(uniqueKeysWithValues: seeds.map { ($0, Double(rawValues[$0, default: 0])) })
        } else {
            let fallbackTotal = fallbackWeights.values.reduce(0, +)
            if fallbackTotal > 0 {
                weightedSource = Dictionary(uniqueKeysWithValues: seeds.map { ($0, Double(fallbackWeights[$0, default: 0])) })
            } else if let last = seeds.last {
                weightedSource = Dictionary(uniqueKeysWithValues: seeds.map { ($0, $0 == last ? 1.0 : 0.0) })
            } else {
                weightedSource = [:]
            }
        }

        let sourceTotal = weightedSource.values.reduce(0, +)
        guard sourceTotal > 0 else {
            return Dictionary(uniqueKeysWithValues: seeds.map { ($0, 0) })
        }

        var values = Dictionary(uniqueKeysWithValues: seeds.map { date in
            let scaled = Double(target) * weightedSource[date, default: 0] / sourceTotal
            return (date, Int(scaled.rounded(.down)))
        })

        var remainder = target - values.values.reduce(0, +)
        let rankedDates = seeds.sorted { lhs, rhs in
            let lhsWeight = weightedSource[lhs, default: 0]
            let rhsWeight = weightedSource[rhs, default: 0]
            if lhsWeight == rhsWeight {
                return lhs < rhs
            }
            return lhsWeight > rhsWeight
        }

        var index = 0
        while remainder > 0 && !rankedDates.isEmpty {
            let date = rankedDates[index % rankedDates.count]
            values[date, default: 0] += 1
            remainder -= 1
            index += 1
        }

        return values
    }

    private func scaledCostValues(
        seeds: [Date],
        rawCosts: [Date: Double],
        target: Double,
        tokenValues: [Date: Int],
        totalTokens: Int
    ) -> [Date: Double] {
        guard target > 0 else {
            return Dictionary(uniqueKeysWithValues: seeds.map { ($0, 0) })
        }

        let rawCostTotal = rawCosts.values.reduce(0, +)
        if rawCostTotal > 0 {
            return Dictionary(uniqueKeysWithValues: seeds.map { date in
                (date, target * rawCosts[date, default: 0] / rawCostTotal)
            })
        }

        guard totalTokens > 0 else {
            return Dictionary(uniqueKeysWithValues: seeds.map { ($0, 0) })
        }

        return Dictionary(uniqueKeysWithValues: seeds.map { date in
            let share = Double(tokenValues[date, default: 0]) / Double(totalTokens)
            return (date, target * share)
        })
    }

    private static func timelineDate(for session: SessionListDTO) -> Date? {
        if let updatedAt = session.updatedAt {
            return Date(timeIntervalSince1970: Double(updatedAt) / 1000)
        }
        if let startedAt = session.startedAt {
            return Date(timeIntervalSince1970: Double(startedAt) / 1000)
        }
        return nil
    }
}
