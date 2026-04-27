import Foundation

struct MemoryCard: Identifiable {
    let id: Int
    let symbol: String
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

@Observable
final class MemoryGame {
    let difficulty: Difficulty
    private(set) var cards: [MemoryCard]
    private(set) var moves: Int = 0
    private(set) var matchedPairs: Int = 0
    private(set) var isComplete: Bool = false
    private(set) var elapsedSeconds: Int = 0
    private(set) var finalMilliseconds: Int = 0

    private var firstSelected: Int? = nil
    private var isLocked: Bool = false
    private var startDate: Date?
    private var timer: Timer?

    let totalPairs: Int

    private static let symbols = [
        "star.fill", "heart.fill", "sun.max.fill", "moon.fill",
        "cloud.fill", "flame.fill", "leaf.fill", "sparkles",
        "bolt.fill", "bell.fill", "gift.fill", "music.note",
        "gamecontroller.fill", "bicycle", "target", "crown.fill",
        "diamond.fill", "shield.fill", "checkmark.circle.fill", "exclamationmark.circle.fill",
        "star.circle.fill", "heart.circle.fill", "square.fill", "triangle.fill"
    ]

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        switch difficulty {
        case .easy:   totalPairs = 6
        case .medium: totalPairs = 10
        case .hard:   totalPairs = 15
        }
        let chosen = Array(Self.symbols.prefix(totalPairs))
        let pairs = (chosen + chosen).enumerated().map { MemoryCard(id: $0.offset, symbol: $0.element) }
        cards = pairs.shuffled()
        startTimer()
    }

    // MARK: - Tap

    func tap(card: MemoryCard) {
        guard !isLocked && !card.isFaceUp && !card.isMatched else { return }
        let idx = cards.firstIndex(where: { $0.id == card.id })!

        if let first = firstSelected {
            cards[idx].isFaceUp = true
            moves += 1

            if cards[first].symbol == cards[idx].symbol {
                cards[first].isMatched = true
                cards[idx].isMatched = true
                matchedPairs += 1
                firstSelected = nil
                if matchedPairs == totalPairs {
                    finalMilliseconds = Int((startDate.map { Date().timeIntervalSince($0) } ?? 0) * 1000)
                    isComplete = true
                    stopTimer()
                }
            } else {
                firstSelected = nil
                isLocked = true
                let a = first, b = idx
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.cards[a].isFaceUp = false
                    self?.cards[b].isFaceUp = false
                    self?.isLocked = false
                }
            }
        } else {
            firstSelected = idx
            cards[idx].isFaceUp = true
        }
    }

    func reset() {
        let chosen = Array(Self.symbols.prefix(totalPairs))
        let pairs = (chosen + chosen).enumerated().map { MemoryCard(id: $0.offset, symbol: $0.element) }
        cards = pairs.shuffled()
        moves = 0
        matchedPairs = 0
        isComplete = false
        finalMilliseconds = 0
        firstSelected = nil
        isLocked = false
        stopTimer()
        startTimer()
    }

    private func startTimer() {
        elapsedSeconds = 0
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    func stopTimer() { timer?.invalidate(); timer = nil }

    deinit { stopTimer() }
}
