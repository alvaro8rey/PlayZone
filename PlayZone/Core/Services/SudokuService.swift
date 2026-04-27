import Foundation

struct SudokuBoard {
    let puzzle: [[Int]]
    let solution: [[Int]]
}

final class SudokuService {
    static let shared = SudokuService()
    private init() {}

    func fetchBoard(difficulty: Difficulty) async throws -> SudokuBoard {
        // Try API first; fall back to local generator if it fails
        if let board = try? await fetchFromAPI(difficulty: difficulty) {
            return board
        }
        return await generateLocally(difficulty: difficulty)
    }

    // MARK: - API (dosuku — no key needed)

    private func fetchFromAPI(difficulty: Difficulty) async throws -> SudokuBoard {
        let url = URL(string: "https://sudoku-api.vercel.app/api/dosuku?query={newboard(limit:1){grids{value,solution,difficulty}}}")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: request)
        let resp = try JSONDecoder().decode(DosukuResponse.self, from: data)
        guard let grid = resp.newboard.grids.first else { throw URLError(.cannotParseResponse) }
        return SudokuBoard(puzzle: grid.value, solution: grid.solution)
    }

    // MARK: - Local generator (fallback, ~50ms)

    private func generateLocally(difficulty: Difficulty) async -> SudokuBoard {
        await Task.detached(priority: .userInitiated) {
            var solution = Array(repeating: Array(repeating: 0, count: 9), count: 9)
            Self.fill(&solution)
            let puzzle = Self.makePuzzle(from: solution, difficulty: difficulty)
            return SudokuBoard(puzzle: puzzle, solution: solution)
        }.value
    }

    private static func fill(_ board: inout [[Int]]) {
        func bt(_ b: inout [[Int]]) -> Bool {
            for r in 0..<9 { for c in 0..<9 where b[r][c] == 0 {
                for n in (1...9).shuffled() {
                    if valid(b, r, c, n) {
                        b[r][c] = n
                        if bt(&b) { return true }
                        b[r][c] = 0
                    }
                }
                return false
            }}
            return true
        }
        _ = bt(&board)
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

    private static func valid(_ b: [[Int]], _ r: Int, _ c: Int, _ n: Int) -> Bool {
        for i in 0..<9 {
            if b[r][i] == n || b[i][c] == n { return false }
        }
        let br = (r/3)*3, bc = (c/3)*3
        for dr in 0..<3 { for dc in 0..<3 where b[br+dr][bc+dc] == n { return false } }
        return true
    }
}

// MARK: - Dosuku response models

private struct DosukuResponse: Decodable {
    let newboard: DosukuBoard
}
private struct DosukuBoard: Decodable {
    let grids: [DosukuGrid]
}
private struct DosukuGrid: Decodable {
    let value: [[Int]]
    let solution: [[Int]]
    let difficulty: String
}
