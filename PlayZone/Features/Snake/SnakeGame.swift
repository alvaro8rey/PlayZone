import Foundation
import SwiftUI

enum SnakeDirection { case up, down, left, right }
enum SnakeState { case idle, playing, over }

struct Point: Equatable { let row: Int; let col: Int }

@Observable
final class SnakeGame {
    let difficulty: Difficulty
    let gridSize: Int = 20

    private(set) var snake: [Point] = []
    private(set) var food: Point = Point(row: 0, col: 0)
    private(set) var direction: SnakeDirection = .right
    private(set) var state: SnakeState = .idle
    private(set) var score: Int = 0

    private var nextDirection: SnakeDirection = .right
    private var timer: Timer?

    private var speed: TimeInterval {
        switch difficulty {
        case .easy:   return 0.12
        case .medium: return 0.08
        case .hard:   return 0.05
        }
    }

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        setupInitial()
    }

    // MARK: - Public

    func start() {
        guard state == .idle else { return }
        state = .playing
        scheduleTimer()
    }

    func changeDirection(_ d: SnakeDirection) {
        switch (direction, d) {
        case (.up, .down), (.down, .up), (.left, .right), (.right, .left): return
        default: nextDirection = d
        }
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        setupInitial()
    }

    // MARK: - Private

    private func setupInitial() {
        let mid = gridSize / 2
        snake = [Point(row: mid, col: mid), Point(row: mid, col: mid - 1), Point(row: mid, col: mid - 2)]
        direction = .right
        nextDirection = .right
        score = 0
        state = .idle
        spawnFood()
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard state == .playing else { return }
        direction = nextDirection

        let head = snake[0]
        var newHead: Point
        switch direction {
        case .up:    newHead = Point(row: head.row - 1, col: head.col)
        case .down:  newHead = Point(row: head.row + 1, col: head.col)
        case .left:  newHead = Point(row: head.row, col: head.col - 1)
        case .right: newHead = Point(row: head.row, col: head.col + 1)
        }

        // Wall collision
        if newHead.row < 0 || newHead.row >= gridSize || newHead.col < 0 || newHead.col >= gridSize {
            gameOver(); return
        }
        // Self collision
        if snake.contains(newHead) { gameOver(); return }

        snake.insert(newHead, at: 0)

        if newHead == food {
            score += 10
            spawnFood()
        } else {
            snake.removeLast()
        }
    }

    private func spawnFood() {
        var candidates: [Point] = []
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                let p = Point(row: r, col: c)
                if !snake.contains(p) { candidates.append(p) }
            }
        }
        food = candidates.randomElement() ?? Point(row: 0, col: 0)
    }

    private func gameOver() {
        state = .over
        timer?.invalidate()
        timer = nil
    }
}
