import Foundation

struct RankingEntry: Identifiable, Codable, Equatable {
    let id: String
    let playerName: String
    let game: String
    let difficulty: String
    let value: Int   // seconds (time games) or points (score games)
    let date: Date

    init(playerName: String, game: GameType, difficulty: Difficulty, value: Int) {
        self.id = UUID().uuidString
        self.playerName = playerName
        self.game = game.rawValue
        self.difficulty = difficulty.rawValue
        self.value = value
        self.date = Date()
    }

    init(id: String, playerName: String, game: String, difficulty: String, value: Int, date: Date) {
        self.id = id
        self.playerName = playerName
        self.game = game
        self.difficulty = difficulty
        self.value = value
        self.date = date
    }

    var formattedValue: String {
        guard let gameType = GameType(rawValue: game) else { return "\(value)" }
        switch gameType.rankingType {
        case .time:
            let totalSeconds = value / 1000
            let ms = (value % 1000) / 10
            return String(format: "%02d:%02d.%02d", totalSeconds / 60, totalSeconds % 60, ms)
        case .score:
            return "\(value) pts"
        case .streak:
            return value == 1 ? "1 victoria" : "\(value) victorias"
        case .moves:
            return value == 1 ? "1 movimiento" : "\(value) movimientos"
        }
    }
}
