import SwiftUI

enum LetterState {
    case unknown, correct, present, absent
}

enum WordleState { case playing, won, lost }

@Observable
final class WordleGame {
    let wordLength: Int
    let maxAttempts = 6

    private(set) var targetWord: String = ""
    private(set) var guesses: [[Character]] = []
    private(set) var letterStates: [[LetterState]] = []
    private(set) var currentTiles: [Character?]
    private(set) var selectedCol: Int = 0
    private(set) var keyboardState: [Character: LetterState] = [:]
    private(set) var state: WordleState = .playing
    private(set) var isLoading = true
    private(set) var score: Int = 0

    var currentRow: Int { guesses.count }
    var isCurrentGuessFull: Bool { currentTiles.allSatisfy { $0 != nil } }

    init(difficulty: Difficulty) {
        self.wordLength = difficulty.wordleLength
        self.currentTiles = Array(repeating: nil, count: difficulty.wordleLength)
        Task { await loadWord() }
    }

    func loadWord() async {
        isLoading = true
        let word = await WordleService.shared.fetchWord(length: wordLength)
        targetWord = word
        isLoading = false
    }

    func addLetter(_ ch: Character) {
        guard state == .playing else { return }
        currentTiles[selectedCol] = ch
        if selectedCol < wordLength - 1 {
            selectedCol += 1
        }
    }

    func deleteLetter() {
        guard state == .playing else { return }
        if currentTiles[selectedCol] != nil {
            currentTiles[selectedCol] = nil
        } else if selectedCol > 0 {
            selectedCol -= 1
            currentTiles[selectedCol] = nil
        }
    }

    func selectCol(_ col: Int) {
        guard state == .playing, col >= 0, col < wordLength else { return }
        selectedCol = col
    }

    func submitGuess() -> Bool {
        guard state == .playing, isCurrentGuessFull else { return false }
        let guess = currentTiles.compactMap { $0 }
        guard guess.count == wordLength else { return false }

        let target = Array(targetWord)
        var states = Array(repeating: LetterState.absent, count: wordLength)
        var remaining = target

        for i in 0..<wordLength where guess[i] == target[i] {
            states[i] = .correct
            remaining[i] = "_"
        }
        for i in 0..<wordLength where states[i] != .correct {
            if let j = remaining.firstIndex(of: guess[i]) {
                states[i] = .present
                remaining[j] = "_"
            }
        }

        guesses.append(guess)
        letterStates.append(states)

        for (ch, st) in zip(guess, states) {
            let cur = keyboardState[ch]
            if cur != .correct {
                if st == .correct || cur == nil || (st == .present && cur == .absent) {
                    keyboardState[ch] = st
                }
            }
        }

        currentTiles = Array(repeating: nil, count: wordLength)
        selectedCol = 0

        if states.allSatisfy({ $0 == .correct }) {
            state = .won
            score = max(1, maxAttempts - currentRow + 1) * wordLength * 10
        } else if guesses.count >= maxAttempts {
            state = .lost
            score = 0
        }

        return true
    }

    func reset() {
        guesses = []
        letterStates = []
        currentTiles = Array(repeating: nil, count: wordLength)
        selectedCol = 0
        keyboardState = [:]
        state = .playing
        score = 0
        Task { await loadWord() }
    }
}

extension Difficulty {
    var wordleLength: Int {
        switch self {
        case .easy:   return 4
        case .medium: return 5
        case .hard:   return 6
        }
    }
}
