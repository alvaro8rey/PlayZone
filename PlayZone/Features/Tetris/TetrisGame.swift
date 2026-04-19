import Foundation
import SwiftUI

enum TetrominoType: CaseIterable {
    case I, O, T, S, Z, J, L

    var cells: [[Bool]] {
        switch self {
        case .I: return [[true, true, true, true]]
        case .O: return [[true, true], [true, true]]
        case .T: return [[false, true, false], [true, true, true]]
        case .S: return [[false, true, true], [true, true, false]]
        case .Z: return [[true, true, false], [false, true, true]]
        case .J: return [[true, false, false], [true, true, true]]
        case .L: return [[false, false, true], [true, true, true]]
        }
    }

    var color: Color {
        switch self {
        case .I: return Color(hex: "06B6D4")
        case .O: return Color(hex: "EAB308")
        case .T: return Color(hex: "A855F7")
        case .S: return Color(hex: "22C55E")
        case .Z: return Color(hex: "EF4444")
        case .J: return Color(hex: "3B82F6")
        case .L: return Color(hex: "F97316")
        }
    }
}

struct TetrisCell: Equatable {
    var filled: Bool
    var color: Color

    static let empty = TetrisCell(filled: false, color: .clear)

    static func == (lhs: TetrisCell, rhs: TetrisCell) -> Bool {
        lhs.filled == rhs.filled
    }
}

struct TetrisPiece {
    var type: TetrominoType
    var cells: [[Bool]]
    var row: Int
    var col: Int

    init(type: TetrominoType, startCol: Int) {
        self.type = type
        self.cells = type.cells
        self.row = 0
        self.col = startCol - cells[0].count / 2
    }

    var color: Color { type.color }

    mutating func rotateClockwise() {
        let rows = cells.count
        let cols = cells[0].count
        var rotated = Array(repeating: Array(repeating: false, count: rows), count: cols)
        for r in 0..<rows {
            for c in 0..<cols {
                rotated[c][rows - 1 - r] = cells[r][c]
            }
        }
        cells = rotated
    }
}

enum TetrisState { case idle, playing, paused, over }

@Observable
final class TetrisGame {
    let difficulty: Difficulty
    static let cols = 10
    static let rows = 20

    private(set) var board: [[TetrisCell]]
    private(set) var current: TetrisPiece?
    private(set) var next: TetrominoType
    private(set) var state: TetrisState = .idle
    private(set) var score: Int = 0
    private(set) var lines: Int = 0
    private(set) var level: Int = 1

    private var timer: Timer?
    private var bag: [TetrominoType] = []

    private var dropInterval: TimeInterval {
        let base: TimeInterval
        switch difficulty {
        case .easy:   base = 0.8
        case .medium: base = 0.5
        case .hard:   base = 0.3
        }
        return max(0.1, base - Double(level - 1) * 0.05)
    }

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.board = Array(repeating: Array(repeating: .empty, count: TetrisGame.cols), count: TetrisGame.rows)
        self.next = TetrominoType.allCases.randomElement()!
        refillBag()
        spawnPiece()
    }

    // MARK: - Public

    func start() {
        guard state == .idle else { return }
        state = .playing
        scheduleTimer()
    }

    func moveLeft() {
        guard state == .playing, var p = current else { return }
        p.col -= 1
        if !collides(p) { current = p }
    }

    func moveRight() {
        guard state == .playing, var p = current else { return }
        p.col += 1
        if !collides(p) { current = p }
    }

    func rotate() {
        guard state == .playing, var p = current else { return }
        p.rotateClockwise()
        // Wall kicks
        if collides(p) {
            p.col += 1
            if collides(p) {
                p.col -= 2
                if collides(p) { return }
            }
        }
        current = p
    }

    func softDrop() {
        guard state == .playing, var p = current else { return }
        p.row += 1
        if collides(p) {
            lockPiece()
        } else {
            current = p
            score += 1
        }
    }

    func hardDrop() {
        guard state == .playing, var p = current else { return }
        var dropped = 0
        while true {
            p.row += 1
            if collides(p) {
                p.row -= 1
                break
            }
            dropped += 1
        }
        current = p
        score += dropped * 2
        lockPiece()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        board = Array(repeating: Array(repeating: .empty, count: TetrisGame.cols), count: TetrisGame.rows)
        score = 0
        lines = 0
        level = 1
        bag = []
        next = Self.drawFromBag(&bag)
        refillBag()
        state = .idle
        spawnPiece()
    }

    // MARK: - Ghost

    var ghostRow: Int {
        guard let p = current else { return 0 }
        var r = p.row
        while true {
            var test = p; test.row = r + 1
            if collides(test) { return r }
            r += 1
        }
    }

    // MARK: - Private

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: dropInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard state == .playing, var p = current else { return }
        p.row += 1
        if collides(p) {
            lockPiece()
        } else {
            current = p
        }
    }

    private func lockPiece() {
        guard let p = current else { return }
        placePiece(p)
        let cleared = clearLines()
        lines += cleared
        score += scoreForLines(cleared)
        level = 1 + lines / 10
        timer?.invalidate()
        spawnPiece()
        if let newPiece = current, collides(newPiece) {
            state = .over
            timer?.invalidate()
        } else if state == .playing {
            scheduleTimer()
        }
    }

    private func placePiece(_ p: TetrisPiece) {
        for r in 0..<p.cells.count {
            for c in 0..<p.cells[r].count {
                guard p.cells[r][c] else { continue }
                let br = p.row + r
                let bc = p.col + c
                if br >= 0 && br < TetrisGame.rows && bc >= 0 && bc < TetrisGame.cols {
                    board[br][bc] = TetrisCell(filled: true, color: p.color)
                }
            }
        }
    }

    private func clearLines() -> Int {
        var cleared = 0
        var newBoard: [[TetrisCell]] = []
        for row in board {
            if row.allSatisfy({ $0.filled }) {
                cleared += 1
            } else {
                newBoard.append(row)
            }
        }
        let empty = Array(repeating: Array(repeating: TetrisCell.empty, count: TetrisGame.cols), count: cleared)
        board = empty + newBoard
        return cleared
    }

    private func scoreForLines(_ n: Int) -> Int {
        let base = [0, 100, 300, 500, 800]
        return (base[min(n, 4)]) * level
    }

    private func collides(_ p: TetrisPiece) -> Bool {
        for r in 0..<p.cells.count {
            for c in 0..<p.cells[r].count {
                guard p.cells[r][c] else { continue }
                let br = p.row + r
                let bc = p.col + c
                if bc < 0 || bc >= TetrisGame.cols { return true }
                if br >= TetrisGame.rows { return true }
                if br >= 0 && board[br][bc].filled { return true }
            }
        }
        return false
    }

    private func spawnPiece() {
        let type = next
        next = drawNext()
        current = TetrisPiece(type: type, startCol: TetrisGame.cols / 2)
    }

    private func drawNext() -> TetrominoType {
        if bag.isEmpty { refillBag() }
        return bag.removeLast()
    }

    private func refillBag() {
        bag = TetrominoType.allCases.shuffled()
    }

    private static func drawFromBag(_ bag: inout [TetrominoType]) -> TetrominoType {
        if bag.isEmpty { bag = TetrominoType.allCases.shuffled() }
        return bag.removeLast()
    }
}
