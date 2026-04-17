import Foundation

struct MineCell: Identifiable {
    let id: Int
    var isMine: Bool = false
    var isRevealed: Bool = false
    var isFlagged: Bool = false
    var adjacentMines: Int = 0
}

struct MinesweeperConfig {
    let rows: Int
    let cols: Int
    let mines: Int

    static func config(for difficulty: Difficulty) -> MinesweeperConfig {
        switch difficulty {
        case .easy:   return MinesweeperConfig(rows: 9,  cols: 9,  mines: 10)
        case .medium: return MinesweeperConfig(rows: 12, cols: 12, mines: 25)
        case .hard:   return MinesweeperConfig(rows: 16, cols: 16, mines: 50)
        }
    }
}

enum MinesweeperState { case idle, playing, won, lost }

@Observable
final class MinesweeperGame {
    let config: MinesweeperConfig
    private(set) var cells: [MineCell]
    private(set) var state: MinesweeperState = .idle
    private(set) var flagCount: Int = 0
    private(set) var elapsedSeconds: Int = 0
    private var timer: Timer?
    private var firstTap = true

    init(difficulty: Difficulty) {
        config = MinesweeperConfig.config(for: difficulty)
        let total = config.rows * config.cols
        cells = (0..<total).map { MineCell(id: $0) }
    }

    // MARK: - Public API

    func reveal(index: Int) {
        guard state != .won && state != .lost else { return }
        guard !cells[index].isFlagged && !cells[index].isRevealed else { return }

        if firstTap {
            firstTap = false
            placeMines(avoiding: index)
            state = .playing
            startTimer()
        }

        if cells[index].isMine {
            revealAll()
            state = .lost
            stopTimer()
            return
        }

        floodReveal(index)
        checkWin()
    }

    func toggleFlag(index: Int) {
        guard state == .playing || state == .idle else { return }
        guard !cells[index].isRevealed else { return }
        cells[index].isFlagged.toggle()
        flagCount += cells[index].isFlagged ? 1 : -1
    }

    func reset() {
        stopTimer()
        firstTap = true
        flagCount = 0
        elapsedSeconds = 0
        state = .idle
        let total = config.rows * config.cols
        cells = (0..<total).map { MineCell(id: $0) }
    }

    var remainingMines: Int { config.mines - flagCount }

    func row(of index: Int) -> Int { index / config.cols }
    func col(of index: Int) -> Int { index % config.cols }
    func index(row: Int, col: Int) -> Int { row * config.cols + col }

    // MARK: - Private

    private func placeMines(avoiding safe: Int) {
        let total = config.rows * config.cols
        var pool = Array(0..<total).filter { $0 != safe }
        pool.shuffle()
        let mineIndices = Set(pool.prefix(config.mines))
        for i in 0..<total {
            cells[i].isMine = mineIndices.contains(i)
        }
        for i in 0..<total {
            guard !cells[i].isMine else { continue }
            cells[i].adjacentMines = neighbors(of: i).filter { cells[$0].isMine }.count
        }
    }

    private func neighbors(of index: Int) -> [Int] {
        let r = row(of: index), c = col(of: index)
        var result: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 {
                guard !(dr == 0 && dc == 0) else { continue }
                let nr = r + dr, nc = c + dc
                guard nr >= 0 && nr < config.rows && nc >= 0 && nc < config.cols else { continue }
                result.append(self.index(row: nr, col: nc))
            }
        }
        return result
    }

    private func floodReveal(_ index: Int) {
        guard !cells[index].isRevealed && !cells[index].isMine && !cells[index].isFlagged else { return }
        cells[index].isRevealed = true
        if cells[index].adjacentMines == 0 {
            neighbors(of: index).forEach { floodReveal($0) }
        }
    }

    private func revealAll() {
        for i in cells.indices {
            if cells[i].isMine { cells[i].isRevealed = true }
        }
    }

    private func checkWin() {
        let unrevealed = cells.filter { !$0.isRevealed && !$0.isMine }.count
        if unrevealed == 0 {
            state = .won
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }
}
