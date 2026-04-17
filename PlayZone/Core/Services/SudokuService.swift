import Foundation

struct SudokuBoard {
    let puzzle: [[Int]]    // 0 = empty cell
    let solution: [[Int]]
}

// Uses sugoku.onrender.com — free, no key needed
final class SudokuService {
    static let shared = SudokuService()
    private init() {}

    func fetchBoard(difficulty: Difficulty) async throws -> SudokuBoard {
        let url = URL(string: "https://sugoku.onrender.com/board?difficulty=\(difficulty.apiKey)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let puzzle = try JSONDecoder().decode(SugokuResponse.self, from: data).board
        let solution = solve(puzzle) ?? puzzle
        return SudokuBoard(puzzle: puzzle, solution: solution)
    }

    // MARK: - Local backtracking solver

    private func solve(_ grid: [[Int]]) -> [[Int]]? {
        var board = grid
        guard backtrack(&board) else { return nil }
        return board
    }

    private func backtrack(_ board: inout [[Int]]) -> Bool {
        for row in 0..<9 {
            for col in 0..<9 where board[row][col] == 0 {
                for num in 1...9 where isValid(board, row: row, col: col, num: num) {
                    board[row][col] = num
                    if backtrack(&board) { return true }
                    board[row][col] = 0
                }
                return false
            }
        }
        return true
    }

    private func isValid(_ board: [[Int]], row: Int, col: Int, num: Int) -> Bool {
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

private struct SugokuResponse: Codable { let board: [[Int]] }
