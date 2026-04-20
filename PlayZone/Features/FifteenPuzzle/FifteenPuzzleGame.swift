import Foundation

@Observable
final class FifteenPuzzleGame {
    let difficulty: Difficulty
    let size: Int

    private(set) var tiles:            [Int] = []   // 0 = empty cell
    private(set) var moves             = 0
    private(set) var isComplete        = false
    private(set) var elapsedSeconds    = 0
    private(set) var finalMilliseconds = 0

    private var timer:     Timer?
    private var startDate  = Date()

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.size       = difficulty.puzzleSize
        generatePuzzle()
    }

    // Tap a tile to slide it into the adjacent empty space.
    func tap(index: Int) {
        guard !isComplete, tiles[index] != 0 else { return }
        guard let emptyIndex = tiles.firstIndex(of: 0) else { return }

        let emptyRow = emptyIndex / size, emptyCol = emptyIndex % size
        let tapRow   = index   / size, tapCol   = index   % size
        guard abs(tapRow - emptyRow) + abs(tapCol - emptyCol) == 1 else { return }

        if timer == nil { startTimer() }
        tiles.swapAt(index, emptyIndex)
        moves += 1
        checkComplete()
    }

    func reset() {
        stopTimer()
        elapsedSeconds     = 0
        finalMilliseconds  = 0
        moves              = 0
        isComplete         = false
        generatePuzzle()
    }

    // MARK: - Puzzle generation

    private func generatePuzzle() {
        let count  = size * size
        tiles = Array(1..<count) + [0]   // solved state

        // Shuffle by applying random valid moves from the solved state → always solvable
        var emptyIdx = count - 1
        for _ in 0..<(count * 200) {
            let emptyRow = emptyIdx / size, emptyCol = emptyIdx % size
            var neighbors: [Int] = []
            if emptyRow > 0          { neighbors.append(emptyIdx - size) }
            if emptyRow < size - 1   { neighbors.append(emptyIdx + size) }
            if emptyCol > 0          { neighbors.append(emptyIdx - 1)    }
            if emptyCol < size - 1   { neighbors.append(emptyIdx + 1)    }
            let pick = neighbors.randomElement()!
            tiles.swapAt(emptyIdx, pick)
            emptyIdx = pick
        }
    }

    private func checkComplete() {
        let count = size * size
        guard tiles == Array(1..<count) + [0] else { return }
        finalMilliseconds = Int(Date().timeIntervalSince(startDate) * 1000)
        isComplete        = true
        stopTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    deinit { stopTimer() }
}

extension Difficulty {
    var puzzleSize: Int {
        switch self {
        case .easy:   return 3   //  8-puzzle
        case .medium: return 4   // 15-puzzle
        case .hard:   return 5   // 24-puzzle
        }
    }
}
