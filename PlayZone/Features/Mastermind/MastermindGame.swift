import Foundation
import SwiftUI

enum PegColor: Int, CaseIterable, Equatable {
    case red, orange, yellow, green, blue, purple

    var color: Color {
        switch self {
        case .red:    return Color(hex: "EF4444")
        case .orange: return Color(hex: "F97316")
        case .yellow: return Color(hex: "EAB308")
        case .green:  return Color(hex: "22C55E")
        case .blue:   return Color(hex: "3B82F6")
        case .purple: return Color(hex: "A855F7")
        }
    }

    var emoji: String {
        switch self {
        case .red:    return "🔴"
        case .orange: return "🟠"
        case .yellow: return "🟡"
        case .green:  return "🟢"
        case .blue:   return "🔵"
        case .purple: return "🟣"
        }
    }
}

struct MastermindRow {
    var pegs: [PegColor?]
    var blacks: Int = 0
    var whites: Int = 0
}

enum MastermindState { case playing, won, lost }

@Observable
final class MastermindGame {
    let difficulty: Difficulty

    var codeLength: Int { difficulty == .hard ? 5 : 4 }

    var maxAttempts: Int {
        switch difficulty {
        case .easy:   return 10
        case .medium: return 8
        case .hard:   return 6
        }
    }

    private var allowRepeats: Bool { difficulty != .easy }

    private(set) var secret: [PegColor] = []
    private(set) var rows: [MastermindRow] = []
    private(set) var current: [PegColor?] = []
    private(set) var state: MastermindState = .playing
    private(set) var score: Int = 0

    var attemptsLeft: Int { maxAttempts - rows.count }
    var canSubmit: Bool { current.allSatisfy { $0 != nil } && state == .playing }

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        setup()
    }

    func tapColor(_ color: PegColor) {
        guard state == .playing else { return }
        guard let idx = current.firstIndex(where: { $0 == nil }) else { return }
        current[idx] = color
    }

    func removePeg(at index: Int) {
        guard state == .playing else { return }
        current[index] = nil
    }

    func submit() {
        guard canSubmit else { return }
        let guess = current.compactMap { $0 }
        let (b, w) = evaluate(guess)
        rows.append(MastermindRow(pegs: current, blacks: b, whites: w))
        if b == codeLength {
            score = (maxAttempts - rows.count + 1) * 100
            state = .won
        } else if rows.count >= maxAttempts {
            state = .lost
        } else {
            current = Array(repeating: nil, count: codeLength)
        }
    }

    func reset() { setup() }

    private func setup() {
        if allowRepeats {
            secret = (0..<codeLength).map { _ in PegColor.allCases.randomElement()! }
        } else {
            secret = Array(PegColor.allCases.shuffled().prefix(codeLength))
        }
        current = Array(repeating: nil, count: codeLength)
        rows = []
        state = .playing
        score = 0
    }

    private func evaluate(_ guess: [PegColor]) -> (Int, Int) {
        var blacks = 0
        var secretRem: [PegColor] = []
        var guessRem: [PegColor] = []
        for i in 0..<codeLength {
            if guess[i] == secret[i] { blacks += 1 }
            else { secretRem.append(secret[i]); guessRem.append(guess[i]) }
        }
        var whites = 0
        for peg in guessRem {
            if let idx = secretRem.firstIndex(of: peg) {
                whites += 1
                secretRem.remove(at: idx)
            }
        }
        return (blacks, whites)
    }
}
