import Foundation

enum SwipeDirection { case up, down, left, right }

@Observable
final class Game2048 {
    let difficulty: Difficulty
    private(set) var board: [[Int]]
    private(set) var score: Int = 0
    private(set) var bestScore: Int = 0
    private(set) var isOver: Bool = false
    private(set) var hasWon: Bool = false
    private var wonShown: Bool = false

    let size: Int
    let goal: Int

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        switch difficulty {
        case .easy:   size = 4; goal = 1024
        case .medium: size = 4; goal = 2048
        case .hard:   size = 4; goal = 4096
        }
        board = Array(repeating: Array(repeating: 0, count: size), count: size)
        bestScore = UserDefaults.standard.integer(forKey: "2048_best_\(difficulty.rawValue)")
        addTile()
        addTile()
    }

    // MARK: - Move

    func swipe(_ direction: SwipeDirection) {
        guard !isOver else { return }
        let previous = board
        switch direction {
        case .left:  board = board.map { slide($0) }
        case .right: board = board.map { Array(slide(Array($0.reversed())).reversed()) }
        case .up:    board = transpose(transpose(board).map { slide($0) })
        case .down:  board = transpose(transpose(board).map { Array(slide(Array($0.reversed())).reversed()) })
        }
        guard board != previous else { return }
        addTile()
        checkState()
    }

    func reset() {
        board = Array(repeating: Array(repeating: 0, count: size), count: size)
        score = 0
        isOver = false
        hasWon = false
        wonShown = false
        addTile()
        addTile()
    }

    // MARK: - Slide

    private func slide(_ row: [Int]) -> [Int] {
        var nums = row.filter { $0 != 0 }
        var i = 0
        while i < nums.count - 1 {
            if nums[i] == nums[i + 1] {
                nums[i] *= 2
                score += nums[i]
                nums.remove(at: i + 1)
            }
            i += 1
        }
        while nums.count < size { nums.append(0) }
        return nums
    }

    private func transpose(_ matrix: [[Int]]) -> [[Int]] {
        guard !matrix.isEmpty else { return [] }
        return (0..<matrix[0].count).map { col in matrix.map { $0[col] } }
    }

    // MARK: - Tile Spawn

    private func addTile() {
        var empty: [(Int, Int)] = []
        for r in 0..<size { for c in 0..<size where board[r][c] == 0 { empty.append((r, c)) } }
        guard let pos = empty.randomElement() else { return }
        board[pos.0][pos.1] = Int.random(in: 0...9) < 9 ? 2 : 4
    }

    // MARK: - State Check

    private func checkState() {
        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(bestScore, forKey: "2048_best_\(difficulty.rawValue)")
        }

        if !hasWon && !wonShown {
            for row in board { if row.contains(goal) { hasWon = true; wonShown = true; return } }
        }

        isOver = !canMove()
    }

    private func canMove() -> Bool {
        for r in 0..<size {
            for c in 0..<size {
                if board[r][c] == 0 { return true }
                if c < size - 1 && board[r][c] == board[r][c+1] { return true }
                if r < size - 1 && board[r][c] == board[r+1][c] { return true }
            }
        }
        return false
    }
}
