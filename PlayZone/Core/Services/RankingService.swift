import Foundation

// MARK: - Protocol

protocol RankingService: AnyObject {
    func save(_ entry: RankingEntry) async throws
    func fetch(game: GameType, difficulty: Difficulty) async throws -> [RankingEntry]
}

// MARK: - Local (UserDefaults) — default implementation, no Firebase needed

final class LocalRankingService: RankingService {
    static let shared = LocalRankingService()
    private init() {}

    private let key = "playzone_rankings_v1"

    private func load() -> [RankingEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([RankingEntry].self, from: data)
        else { return [] }
        return entries
    }

    private func persist(_ entries: [RankingEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func save(_ entry: RankingEntry) async throws {
        var entries = load()
        entries.append(entry)
        persist(entries)
    }

    func fetch(game: GameType, difficulty: Difficulty) async throws -> [RankingEntry] {
        let filtered = load().filter { $0.game == game.rawValue && $0.difficulty == difficulty.rawValue }
        let sorted = game.rankingType == .time
            ? filtered.sorted { $0.value < $1.value }
            : filtered.sorted { $0.value > $1.value }
        return Array(sorted.prefix(10))
    }
}
