import Foundation

struct SudokuBoard {
    let puzzle: [[Int]]    // 0 = empty cell
    let solution: [[Int]]
}

// Generates Sudoku boards locally — instant, no network needed.
final class SudokuService {
    static let shared = SudokuService()
    private init() {}

    func fetchBoard(difficulty: Difficulty) async throws -> SudokuBoard {
        // Run on background thread so UI doesn't block
        return try await Task.detached(priority: .userInitiated) {
            guard let board = Self.generate() else { throw SudokuError.generationFailed }
            let puzzle = Self.makePuzzle(from: board, difficulty: difficulty)
            return SudokuBoard(puzzle: puzzle, solution: board)
        }.value
    }

    // MARK: - Generator

    private static func generate() -> [[Int]]? {
        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        guard fill(&board) else { return nil }
        return board
    }

    private static func fill(_ board: inout [[Int]]) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 where board[row][col] == 0 {
                for num in (1...9).shuffled() {
                    guard isValid(board, row: row, col: col, num: num) else { continue }
                    board[row][col] = num
                    if fill(&board) { return true }
                    board[row][col] = 0
                }
                return false
            }
        }
        return true
    }

    private static func makePuzzle(from solution: [[Int]], difficulty: Difficulty) -> [[Int]] {
        let removals: Int
        switch difficulty {
        case .easy:   removals = 35
        case .medium: removals = 46
        case .hard:   removals = 54
        }
        var puzzle = solution
        for pos in (0..<81).shuffled().prefix(removals) {
            puzzle[pos / 9][pos % 9] = 0
        }
        return puzzle
    }

    private static func isValid(_ board: [[Int]], row: Int, col: Int, num: Int) -> Bool {
        for i in 0..<9 {
            if board[row][i] == num || board[i][col] == num { return false }
        }
        let br = (row / 3) * 3, bc = (col / 3) * 3
        for r in br..<br+3 {
            for c in bc..<bc+3 where board[r][c] == num { return false }
        }
        return true
    }
}

private enum SudokuError: Error { case generationFailed }
