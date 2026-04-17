import Foundation

struct SudokuBoard {
    let puzzle: [[Int]]    // 0 = empty cell
    let solution: [[Int]]
}

final class SudokuService {
    static let shared = SudokuService()
    private init() {}

    private let apiKey = "vXl_Msn8DZKj-TYZE5cMwha_Q4olWA0RTR2U_d_l-14"
    private let baseURL = "https://you-do-sudoku-api.vercel.app/api"

    func fetchBoard(difficulty: Difficulty) async throws -> SudokuBoard {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "difficulty", value: difficulty.apiKey)]
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(YouDoSudokuResponse.self, from: data)
        let puzzle   = stringToGrid(response.puzzle)
        let solution = stringToGrid(response.solution)
        return SudokuBoard(puzzle: puzzle, solution: solution)
    }

    // MARK: - Helpers

    private func stringToGrid(_ str: String) -> [[Int]] {
        let digits = str.compactMap { $0.wholeNumberValue }
        return stride(from: 0, to: 81, by: 9).map { Array(digits[$0..<$0+9]) }
    }
}

private struct YouDoSudokuResponse: Codable {
    let difficulty: String
    let puzzle: String
    let solution: String
}
