import Foundation

@Observable
final class SudokuGame {
    let difficulty: Difficulty
    private(set) var puzzle: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    private(set) var solution: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    private(set) var board: [[Int]] = Array(repeating: Array(repeating: 0, count: 9), count: 9)
    private(set) var notes: [[[Bool]]] = Array(repeating: Array(repeating: Array(repeating: false, count: 9), count: 9), count: 9)
    private(set) var selected: (row: Int, col: Int)? = nil
    private(set) var mistakes: Int = 0
    private(set) var isComplete: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String? = nil
    private(set) var elapsedSeconds: Int = 0
    private(set) var notesMode: Bool = false
    private var timer: Timer?

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let board = try await SudokuService.shared.fetchBoard(difficulty: difficulty)
            puzzle = board.puzzle
            solution = board.solution
            self.board = board.puzzle
            notes = Array(repeating: Array(repeating: Array(repeating: false, count: 9), count: 9), count: 9)
            mistakes = 0
            isComplete = false
            selected = nil
            startTimer()
        } catch {
            errorMessage = "No se pudo cargar el Sudoku. Revisa tu conexión."
        }
        isLoading = false
    }

    // MARK: - Input

    func select(row: Int, col: Int) {
        if let s = selected, s.row == row && s.col == col {
            selected = nil
        } else {
            selected = (row, col)
        }
    }

    func input(number: Int) {
        guard let sel = selected else { return }
        guard puzzle[sel.row][sel.col] == 0 else { return }

        if number == 0 {
            board[sel.row][sel.col] = 0
            notes[sel.row][sel.col] = Array(repeating: false, count: 9)
            return
        }

        if notesMode {
            notes[sel.row][sel.col][number - 1].toggle()
            return
        }

        board[sel.row][sel.col] = number
        notes[sel.row][sel.col] = Array(repeating: false, count: 9)

        if solution[sel.row][sel.col] != number {
            mistakes += 1
        }

        checkComplete()
    }

    func toggleNotesMode() { notesMode.toggle() }

    // MARK: - Helpers

    var highlightedCells: Set<String> {
        guard let sel = selected else { return [] }
        var result: Set<String> = []
        let boxR = (sel.row / 3) * 3, boxC = (sel.col / 3) * 3
        for i in 0..<9 {
            result.insert("\(sel.row)_\(i)")
            result.insert("\(i)_\(sel.col)")
        }
        for r in boxR..<boxR+3 {
            for c in boxC..<boxC+3 { result.insert("\(r)_\(c)") }
        }
        return result
    }

    func isOriginal(row: Int, col: Int) -> Bool { puzzle[row][col] != 0 }

    func isConflict(row: Int, col: Int) -> Bool {
        let val = board[row][col]
        guard val != 0 else { return false }
        return solution[row][col] != val
    }

    // MARK: - Timer

    func stopTimer() { timer?.invalidate(); timer = nil }

    private func startTimer() {
        elapsedSeconds = 0
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func checkComplete() {
        for r in 0..<9 {
            for c in 0..<9 where board[r][c] != solution[r][c] { return }
        }
        isComplete = true
        stopTimer()
    }
}
