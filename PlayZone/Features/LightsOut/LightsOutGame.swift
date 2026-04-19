import Foundation

@Observable
final class LightsOutGame {
    let difficulty: Difficulty
    let size: Int

    private(set) var grid:       [[Bool]] = []
    private(set) var moves       = 0
    private(set) var isComplete  = false

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.size       = difficulty.lightsOutSize
        generatePuzzle()
    }

    func tap(_ row: Int, _ col: Int) {
        guard !isComplete else { return }
        toggle(row, col)
        moves += 1
        checkComplete()
    }

    func reset() {
        moves      = 0
        isComplete = false
        generatePuzzle()
    }

    // MARK: - Private

    private func toggle(_ row: Int, _ col: Int) {
        for (dr, dc) in [(0,0), (-1,0), (1,0), (0,-1), (0,1)] {
            let r = row + dr, c = col + dc
            if r >= 0 && r < size && c >= 0 && c < size {
                grid[r][c].toggle()
            }
        }
    }

    private func generatePuzzle() {
        grid = Array(repeating: Array(repeating: false, count: size), count: size)
        // Apply random taps from the solved (all-off) state → always solvable
        let tapCount = Int.random(in: (size * 2)...(size * size))
        for _ in 0..<tapCount {
            toggle(Int.random(in: 0..<size), Int.random(in: 0..<size))
        }
        // If we accidentally ended up solved again, force one tap
        if grid.allSatisfy({ $0.allSatisfy({ !$0 }) }) {
            toggle(size / 2, size / 2)
        }
    }

    private func checkComplete() {
        isComplete = grid.allSatisfy { $0.allSatisfy { !$0 } }
    }
}

extension Difficulty {
    var lightsOutSize: Int {
        switch self {
        case .easy:   return 3
        case .medium: return 5
        case .hard:   return 7
        }
    }
}
