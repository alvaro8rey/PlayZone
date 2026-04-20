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

@MainActor
@Observable
final class NonogramGame {
    let difficulty: Difficulty
    let size: Int

    private(set) var marks:            [[NonogramCellState]] = []
    private(set) var rowClues:         [[Int]] = []
    private(set) var colClues:         [[Int]] = []
    private(set) var isComplete        = false
    private(set) var isLoading         = true
    private(set) var elapsedSeconds    = 0
    private(set) var finalMilliseconds = 0
    private(set) var isUnique          = true

    private var solution:  [[Bool]] = []
    private var timer:     Timer?
    private var startDate  = Date()

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.size       = difficulty.nonogramSize
    }

    // MARK: - Async load (call from .task in the view)

    func load() async {
        isLoading = true
        let s = size
        let data = await Task.detached(priority: .userInitiated) {
            NonogramGame.computePuzzle(size: s)
        }.value
        solution   = data.solution
        rowClues   = data.rowClues
        colClues   = data.colClues
        isUnique   = data.isUnique
        marks      = Array(repeating: Array(repeating: .empty, count: s), count: s)
        isComplete = false
        isLoading  = false
    }

    // MARK: - Game actions

    func tap(_ row: Int, _ col: Int) {
        guard !isComplete, !isLoading else { return }
        if timer == nil { startTimer() }
        marks[row][col] = marks[row][col].next
        checkComplete()
    }

    func reset() {
        stopTimer()
        elapsedSeconds    = 0
        finalMilliseconds = 0
        isComplete        = false
        Task { await load() }
    }

    // MARK: - Clue helpers (instance — used by view)

    func isRowComplete(_ r: Int) -> Bool {
        NonogramGame.computeClues((0..<size).map { marks[r][$0] == .filled }) == rowClues[r]
    }

    func isColComplete(_ c: Int) -> Bool {
        NonogramGame.computeClues((0..<size).map { marks[$0][c] == .filled }) == colClues[c]
    }

    // Validates against the clues so any logically equivalent solution is accepted.
    private func checkComplete() {
        for r in 0..<size {
            if NonogramGame.computeClues((0..<size).map { marks[r][$0] == .filled }) != rowClues[r] { return }
        }
        for c in 0..<size {
            if NonogramGame.computeClues((0..<size).map { marks[$0][c] == .filled }) != colClues[c] { return }
        }
        finalMilliseconds = Int(Date().timeIntervalSince(startDate) * 1000)
        isComplete = true
        stopTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.elapsedSeconds += 1 }
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    deinit { timer?.invalidate() }
}

// MARK: - Pure computation (nonisolated — safe to call from Task.detached)

private extension NonogramGame {

    struct PuzzleData {
        let solution: [[Bool]]
        let rowClues: [[Int]]
        let colClues: [[Int]]
        let isUnique: Bool
    }

    nonisolated static func computePuzzle(size: Int) -> PuzzleData {
        var fallbackSol: [[Bool]] = []
        var fallbackRow: [[Int]]  = []
        var fallbackCol: [[Int]]  = []

        for attempt in 0..<200 {
            let sol    = (0..<size).map { _ in (0..<size).map { _ in Double.random(in: 0...1) < 0.55 } }
            let rClues = sol.map { computeClues($0) }
            let cClues = (0..<size).map { c in computeClues((0..<size).map { sol[$0][c] }) }

            if attempt == 0 { fallbackSol = sol; fallbackRow = rClues; fallbackCol = cClues }

            if hasSingleSolution(size: size, rowClues: rClues, colClues: cClues) {
                return PuzzleData(solution: sol, rowClues: rClues, colClues: cClues, isUnique: true)
            }
        }
        return PuzzleData(solution: fallbackSol, rowClues: fallbackRow, colClues: fallbackCol, isUnique: false)
    }

    nonisolated static func computeClues(_ line: [Bool]) -> [Int] {
        var clues: [Int] = []; var run = 0
        for cell in line {
            if cell         { run += 1 }
            else if run > 0 { clues.append(run); run = 0 }
        }
        if run > 0 { clues.append(run) }
        return clues.isEmpty ? [0] : clues
    }

    // MARK: Uniqueness solver

    enum SCell: Equatable { case unknown, on, off }
    typealias SLine = [SCell]
    typealias SGrid = [[SCell]]

    nonisolated static func hasSingleSolution(size: Int, rowClues: [[Int]], colClues: [[Int]]) -> Bool {
        var grid  = SGrid(repeating: SLine(repeating: .unknown, count: size), count: size)
        var count = 0
        solve(&grid, count: &count, size: size, rowClues: rowClues, colClues: colClues)
        return count == 1
    }

    nonisolated static func solve(_ grid: inout SGrid, count: inout Int,
                                  size: Int, rowClues: [[Int]], colClues: [[Int]]) {
        guard count < 2 else { return }

        var changed = true
        while changed {
            changed = false
            for r in 0..<size {
                let line = (0..<size).map { grid[r][$0] }
                guard let newLine = deduce(line, clue: rowClues[r]) else { return }
                for c in 0..<size where grid[r][c] == .unknown && newLine[c] != .unknown {
                    grid[r][c] = newLine[c]; changed = true
                }
            }
            for c in 0..<size {
                let line = (0..<size).map { grid[$0][c] }
                guard let newLine = deduce(line, clue: colClues[c]) else { return }
                for r in 0..<size where grid[r][c] == .unknown && newLine[r] != .unknown {
                    grid[r][c] = newLine[r]; changed = true
                }
            }
        }

        var pivot: (Int, Int)? = nil
        outer: for r in 0..<size {
            for c in 0..<size where grid[r][c] == .unknown { pivot = (r, c); break outer }
        }
        guard let (r, c) = pivot else { count += 1; return }

        var g1 = grid; g1[r][c] = .on
        solve(&g1, count: &count, size: size, rowClues: rowClues, colClues: colClues)
        guard count < 2 else { return }
        var g2 = grid; g2[r][c] = .off
        solve(&g2, count: &count, size: size, rowClues: rowClues, colClues: colClues)
    }

    nonisolated static func deduce(_ line: SLine, clue: [Int]) -> SLine? {
        if clue == [0] {
            return line.contains(.on) ? nil : SLine(repeating: .off, count: line.count)
        }
        let n = line.count
        var defOn  = Array(repeating: true,  count: n)
        var defOff = Array(repeating: true,  count: n)
        var found  = false
        var done   = false
        var current = Array(repeating: false, count: n)

        func place(gi: Int, pos: Int) {
            guard !done else { return }
            if gi == clue.count {
                if pos < n {
                    for i in pos..<n { if line[i] == .on { return } }
                }
                for c in 0..<n {
                    if current[c] { defOff[c] = false }
                    else          { defOn[c]  = false }
                }
                found = true
                done = !(0..<n).contains { c in line[c] == .unknown && (defOn[c] || defOff[c]) }
                return
            }
            let remaining = clue[gi...].reduce(0, +) + (clue.count - gi - 1)
            guard pos + remaining <= n else { return }
            let len = clue[gi], lastStart = n - remaining
            for start in pos...lastStart {
                guard !done else { return }
                var ok = true
                for i in pos..<start { if line[i] == .on { ok = false; break } }
                if !ok { break }
                ok = true
                for i in start..<(start + len) { if line[i] == .off { ok = false; break } }
                if ok && start + len < n && line[start + len] == .on { ok = false }
                if ok {
                    for i in start..<(start + len) { current[i] = true }
                    place(gi: gi + 1, pos: start + len + 1)
                    for i in start..<(start + len) { current[i] = false }
                }
            }
        }

        place(gi: 0, pos: 0)
        guard found else { return nil }
        var result = line
        for c in 0..<n where line[c] == .unknown {
            if defOn[c]  { result[c] = .on  }
            if defOff[c] { result[c] = .off }
        }
        return result
    }
}

// MARK: - Difficulty extension

extension Difficulty {
    var nonogramSize: Int {
        switch self {
        case .easy:   return 5
        case .medium: return 10
        case .hard:   return 15
        }
    }
}
