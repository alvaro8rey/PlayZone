import Foundation

enum NonogramCellState {
    case empty, filled, crossed

    var next: NonogramCellState {
        switch self {
        case .empty:   return .filled
        case .filled:  return .crossed
        case .crossed: return .empty
        }
    }
}

@Observable
final class NonogramGame {
    let difficulty: Difficulty
    let size: Int

    private(set) var marks:    [[NonogramCellState]] = []
    private(set) var rowClues: [[Int]] = []
    private(set) var colClues: [[Int]] = []
    private(set) var isComplete     = false
    private(set) var elapsedSeconds = 0
    private(set) var finalMilliseconds = 0

    private var solution:  [[Bool]] = []
    private var timer:     Timer?
    private var startDate  = Date()

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.size       = difficulty.nonogramSize
        generatePuzzle()
    }

    func tap(_ row: Int, _ col: Int) {
        guard !isComplete else { return }
        if timer == nil { startTimer() }
        marks[row][col] = marks[row][col].next
        checkComplete()
    }

    func reset() {
        stopTimer()
        elapsedSeconds     = 0
        finalMilliseconds  = 0
        isComplete         = false
        generatePuzzle()
    }

    // MARK: - Private

    private func generatePuzzle() {
        solution = (0..<size).map { _ in (0..<size).map { _ in Double.random(in: 0...1) < 0.55 } }
        marks    = Array(repeating: Array(repeating: .empty, count: size), count: size)
        rowClues = solution.map { computeClues($0) }
        colClues = (0..<size).map { c in computeClues((0..<size).map { solution[$0][c] }) }
        isComplete = false
    }

    private func computeClues(_ line: [Bool]) -> [Int] {
        var clues: [Int] = []
        var run = 0
        for cell in line {
            if cell      { run += 1 }
            else if run > 0 { clues.append(run); run = 0 }
        }
        if run > 0 { clues.append(run) }
        return clues.isEmpty ? [0] : clues
    }

    // Validates against clues so any equivalent solution is accepted.
    private func checkComplete() {
        for r in 0..<size {
            let rowFilled = (0..<size).map { marks[r][$0] == .filled }
            if computeClues(rowFilled) != rowClues[r] { return }
        }
        for c in 0..<size {
            let colFilled = (0..<size).map { marks[$0][c] == .filled }
            if computeClues(colFilled) != colClues[c] { return }
        }
        finalMilliseconds = Int(Date().timeIntervalSince(startDate) * 1000)
        isComplete = true
        stopTimer()
    }

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
    var nonogramSize: Int {
        switch self {
        case .easy:   return 5
        case .medium: return 10
        case .hard:   return 15
        }
    }
}
