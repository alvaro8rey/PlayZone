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
    private(set) var currentGuess: String = ""
    private(set) var keyboardState: [Character: LetterState] = [:]
    private(set) var state: WordleState = .playing
    private(set) var isLoading = true
    private(set) var score: Int = 0

    var currentRow: Int { guesses.count }
    var attemptsLeft: Int { maxAttempts - currentRow }

    init(difficulty: Difficulty) {
        self.wordLength = difficulty.wordleLength
        Task { await loadWord() }
    }

    func loadWord() async {
        isLoading = true
        let word = await WordleService.shared.fetchWord(length: wordLength)
        targetWord = word
        isLoading = false
    }

    func addLetter(_ ch: Character) {
        guard state == .playing, currentGuess.count < wordLength else { return }
        currentGuess.append(ch)
    }

    func deleteLetter() {
        guard state == .playing, !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
    }

    func submitGuess() -> Bool {
        guard state == .playing, currentGuess.count == wordLength else { return false }
        let guess = Array(currentGuess.lowercased())
        let target = Array(targetWord)
        var states = Array(repeating: LetterState.absent, count: wordLength)
        var remaining = target

        // First pass: correct
        for i in 0..<wordLength {
            if guess[i] == target[i] {
                states[i] = .correct
                remaining[i] = "_"
            }
        }
        // Second pass: present
        for i in 0..<wordLength where states[i] != .correct {
            if let j = remaining.firstIndex(of: guess[i]) {
                states[i] = .present
                remaining[j] = "_"
            }
        }

        guesses.append(guess)
        letterStates.append(states)

        for (ch, st) in zip(guess, states) {
            let current = keyboardState[ch]
            if current != .correct {
                if st == .correct || current == nil || (st == .present && current == .absent) {
                    keyboardState[ch] = st
                }
            }
        }

        currentGuess = ""

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
        currentGuess = ""
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
