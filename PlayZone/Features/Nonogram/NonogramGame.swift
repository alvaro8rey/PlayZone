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
    private(set) var isComplete        = false
    private(set) var elapsedSeconds    = 0
    private(set) var finalMilliseconds = 0
    // Exposed so the view can show whether this puzzle is uniquely solvable
    private(set) var isUnique          = true

    private var solution: [[Bool]] = []
    private var timer:    Timer?
    private var startDate = Date()

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

    // MARK: - Puzzle generation

    private func generatePuzzle() {
        // Try up to 200 random grids; keep the first one that is uniquely solvable.
        // Fall back to the first candidate if none passes.
        var fallbackSol:    [[Bool]] = []
        var fallbackRow:    [[Int]]  = []
        var fallbackCol:    [[Int]]  = []

        let t0 = Date()
        for attempt in 0..<200 {
            let sol = (0..<size).map { _ in
                (0..<size).map { _ in Double.random(in: 0...1) < 0.55 }
            }
            let rClues = sol.map { computeClues($0) }
            let cClues = (0..<size).map { c in computeClues((0..<size).map { sol[$0][c] }) }

            if attempt == 0 {
                fallbackSol = sol; fallbackRow = rClues; fallbackCol = cClues
            }

            rowClues = rClues
            colClues = cClues

            if hasSingleSolution() {
                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                print("[Nonogram] ✅ Unique puzzle found in \(attempt + 1) attempt(s) — \(ms) ms (\(size)×\(size))")
                solution  = sol
                isUnique  = true
                marks     = Array(repeating: Array(repeating: .empty, count: size), count: size)
                isComplete = false
                return
            }
        }

        // Fallback: use a non-unique puzzle (ambiguous clues)
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        print("[Nonogram] ⚠️ No unique puzzle found in 200 attempts — using non-unique fallback (\(size)×\(size), \(ms) ms)")
        solution  = fallbackSol
        rowClues  = fallbackRow
        colClues  = fallbackCol
        isUnique  = false
        marks     = Array(repeating: Array(repeating: .empty, count: size), count: size)
        isComplete = false
    }

    func computeClues(_ line: [Bool]) -> [Int] {
        var clues: [Int] = []
        var run = 0
        for cell in line {
            if cell         { run += 1 }
            else if run > 0 { clues.append(run); run = 0 }
        }
        if run > 0 { clues.append(run) }
        return clues.isEmpty ? [0] : clues
    }

    func isRowComplete(_ r: Int) -> Bool {
        computeClues((0..<size).map { marks[r][$0] == .filled }) == rowClues[r]
    }

    func isColComplete(_ c: Int) -> Bool {
        computeClues((0..<size).map { marks[$0][c] == .filled }) == colClues[c]
    }

    // Validates against the clues so any logically equivalent solution is accepted.
    private func checkComplete() {
        for r in 0..<size {
            if computeClues((0..<size).map { marks[r][$0] == .filled }) != rowClues[r] { return }
        }
        for c in 0..<size {
            if computeClues((0..<size).map { marks[$0][c] == .filled }) != colClues[c] { return }
        }
        finalMilliseconds = Int(Date().timeIntervalSince(startDate) * 1000)
        isComplete = true
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

// MARK: - Uniqueness solver

private extension NonogramGame {

    enum SCell: Equatable { case unknown, on, off }
    typealias SLine = [SCell]
    typealias SGrid = [[SCell]]

    // Returns true iff the current rowClues / colClues have exactly one solution.
    func hasSingleSolution() -> Bool {
        var grid  = SGrid(repeating: SLine(repeating: .unknown, count: size), count: size)
        var count = 0
        solve(&grid, count: &count)
        return count == 1
    }

    // Propagates constraints, then branches on the first ambiguous cell.
    // Stops as soon as count reaches 2 (not unique).
    func solve(_ grid: inout SGrid, count: inout Int) {
        guard count < 2 else { return }

        // Constraint propagation — repeat until stable
        var changed = true
        while changed {
            changed = false
            for r in 0..<size {
                let line = (0..<size).map { grid[r][$0] }
                guard let newLine = deduce(line, clue: rowClues[r]) else { return } // contradiction
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

        // Find first unknown cell
        var pivot: (Int, Int)? = nil
        outer: for r in 0..<size {
            for c in 0..<size where grid[r][c] == .unknown { pivot = (r, c); break outer }
        }

        guard let (r, c) = pivot else {
            count += 1   // Fully solved → found a solution
            return
        }

        // Branch: try .on, then .off
        var g1 = grid; g1[r][c] = .on
        solve(&g1, count: &count)
        guard count < 2 else { return }
        var g2 = grid; g2[r][c] = .off
        solve(&g2, count: &count)
    }

    // Returns the line with any newly deducible cells filled in, or nil on contradiction.
    //
    // Algorithm: enumerate every valid placement of the clue groups consistent with
    // the current partial line.  A cell is forced-on if it is on in ALL valid placements;
    // forced-off if it is off in ALL valid placements.  An early-exit flag stops
    // enumeration as soon as no cell can benefit from further placements.
    func deduce(_ line: SLine, clue: [Int]) -> SLine? {
        if clue == [0] {
            return line.contains(.on) ? nil : SLine(repeating: .off, count: line.count)
        }

        let n = line.count
        var defOn   = Array(repeating: true, count: n)  // forced on in every placement seen so far
        var defOff  = Array(repeating: true, count: n)  // forced off in every placement seen so far
        var found   = false
        var done    = false                             // early-exit flag
        var current = Array(repeating: false, count: n) // working placement (true = on)

        func place(gi: Int, pos: Int) {
            guard !done else { return }

            // Base case: all groups placed
            if gi == clue.count {
                // pos can equal n+1 when the last group ends on the last cell (start+len=n).
                // Guard against the invalid range pos..<n when pos > n.
                if pos < n {
                    for i in pos..<n { if line[i] == .on { return } }  // trailing .on = invalid
                }
                // Record this placement into the intersection arrays
                for c in 0..<n {
                    if current[c] { defOff[c] = false }
                    else          { defOn[c]  = false }
                }
                found = true
                // Early exit: if no unknown cell can still be deduced, stop enumerating
                done = !(0..<n).contains { c in line[c] == .unknown && (defOn[c] || defOff[c]) }
                return
            }

            let remaining = clue[gi...].reduce(0, +) + (clue.count - gi - 1)
            guard pos + remaining <= n else { return }

            let len       = clue[gi]
            let lastStart = n - remaining

            for start in pos...lastStart {
                guard !done else { return }

                // Gap cells before this group must not be forced-on
                var ok = true
                for i in pos..<start {
                    if line[i] == .on { ok = false; break }
                }
                if !ok { break } // skipping a forced-on cell → no later start is valid

                // Group cells must not be forced-off
                ok = true
                for i in start..<(start + len) {
                    if line[i] == .off { ok = false; break }
                }
                // Cell immediately after group must not be forced-on (mandatory gap)
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
