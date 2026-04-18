import SwiftUI

enum ColorMatchState { case playing, showingResult, finished }

struct ColorRound {
    let targetR: Double
    let targetG: Double
    let targetB: Double
    var score: Int?

    var targetColor: Color {
        Color(red: targetR / 255, green: targetG / 255, blue: targetB / 255)
    }
}

@Observable
final class ColorMatchGame {
    let difficulty: Difficulty
    private(set) var rounds: [ColorRound]
    private(set) var currentIndex: Int = 0
    private(set) var state: ColorMatchState = .playing

    var totalScore: Int { rounds.compactMap(\.score).reduce(0, +) }
    var maxScore:   Int { rounds.count * 100 }
    var currentRound: ColorRound { rounds[currentIndex] }

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.rounds = Self.makeRounds(difficulty.colorMatchRounds)
    }

    func reset() {
        rounds = Self.makeRounds(difficulty.colorMatchRounds)
        currentIndex = 0
        state = .playing
    }

    func confirmGuess(r: Double, g: Double, b: Double) {
        let dr = currentRound.targetR - r
        let dg = currentRound.targetG - g
        let db = currentRound.targetB - b
        let dist = (dr * dr + dg * dg + db * db).squareRoot()
        let pct  = max(0.0, 1 - dist / (255 * 255 * 3.0).squareRoot())
        rounds[currentIndex].score = Int((pct * 100).rounded())
        state = .showingResult
    }

    func nextRound() {
        if currentIndex + 1 < rounds.count {
            currentIndex += 1
            state = .playing
        } else {
            state = .finished
        }
    }

    private static func makeRounds(_ count: Int) -> [ColorRound] {
        (0..<count).map { _ in
            ColorRound(
                targetR: Double.random(in: 30...225),
                targetG: Double.random(in: 30...225),
                targetB: Double.random(in: 30...225)
            )
        }
    }
}

extension Difficulty {
    var colorMatchRounds: Int {
        switch self { case .easy: return 5; case .medium: return 8; case .hard: return 12 }
    }
}
