import Foundation

struct SudokuBoard {
    let puzzle: [[Int]]    // 0 = empty cell
    let solution: [[Int]]
}

final class SudokuService {
    static let shared = SudokuService()
    private init() {}

    func fetchBoard(difficulty: Difficulty) async throws -> SudokuBoard {
        guard let url = URL(string: "https://youdosudoku.com/api/") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "difficulty": difficulty.apiKey,
            "solution": true
        ])

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let puzzleStr   = json["puzzle"]   as? String,
              let solutionStr = json["solution"] as? String
        else { throw URLError(.cannotParseResponse) }

        return SudokuBoard(
            puzzle:   stringToGrid(puzzleStr),
            solution: stringToGrid(solutionStr)
        )
    }

    private func stringToGrid(_ str: String) -> [[Int]] {
        let digits = str.compactMap { $0.wholeNumberValue }
        return stride(from: 0, to: 81, by: 9).map { Array(digits[$0..<$0+9]) }
    }
}
