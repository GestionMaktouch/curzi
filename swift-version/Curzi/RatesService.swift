import Foundation

/// Mid-market rates against USD from the Exchange Rate API's free feed, cached for offline use.
actor RatesService {
    private let url = URL(string: "https://open.er-api.com/v6/latest/USD")!
    private var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("rates.json")
    }

    struct Loaded { let feed: RatesFeed; let stale: Bool }

    func load() async throws -> Loaded {
        let cached = try? JSONDecoder().decode(RatesFeed.self, from: Data(contentsOf: cacheURL))
        do {
            let fresh = try await fetch()
            try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? JSONEncoder().encode(fresh).write(to: cacheURL, options: .atomic)
            return Loaded(feed: fresh, stale: false)
        } catch {
            if let cached { return Loaded(feed: cached, stale: true) }
            throw error
        }
    }

    private struct Answer: Decodable {
        let result: String
        let time_last_update_unix: TimeInterval
        let rates: [String: Double]
    }

    private func fetch() async throws -> RatesFeed {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let answer = try JSONDecoder().decode(Answer.self, from: data)
        guard answer.result == "success", answer.rates["USD"] != nil else { throw URLError(.cannotParseResponse) }
        let updatedAt = Date(timeIntervalSince1970: answer.time_last_update_unix)
        let day = ISO8601DateFormatter().string(from: updatedAt).prefix(10)
        return RatesFeed(date: String(day), updatedAt: updatedAt,
                         rates: answer.rates.filter { $0.value.isFinite && $0.value > 0 })
    }
}
