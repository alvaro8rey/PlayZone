import SwiftUI

enum BreakoutState { case idle, playing, over, won }

@Observable
final class BreakoutGame {

    // MARK: - Board constants
    static let boardW: CGFloat = 375
    static let boardH: CGFloat = 620

    static let brickCols   = 8
    static let brickMargin: CGFloat = 8
    static let brickGap:    CGFloat = 4
    static let brickH:      CGFloat = 16
    static let brickStartY: CGFloat = 60

    static var brickW: CGFloat {
        (boardW - brickMargin * 2 - CGFloat(brickCols - 1) * brickGap) / CGFloat(brickCols)
    }

    static let paddleH:  CGFloat = 12
    static let paddleY:  CGFloat = 575
    static let ballR:    CGFloat = 8

    // MARK: - State

    let difficulty: Difficulty
    private(set) var bricks: [[Bool]]
    private(set) var paddleX: CGFloat
    private(set) var ballPos:  CGPoint
    private(set) var ballVel:  CGPoint
    private(set) var lives = 3
    private(set) var state: BreakoutState = .idle
    private(set) var displaySeconds: Int = 0
    private(set) var finalMilliseconds: Int = 0

    var paddleW:  CGFloat { difficulty.breakoutPaddleW }
    var brickRows: Int    { difficulty.breakoutBrickRows }

    private var timer: Timer?
    private var lastTick: Date?
    private var startDate: Date?

    // MARK: - Init / Reset

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        self.bricks   = Self.freshBricks(rows: difficulty.breakoutBrickRows)
        self.paddleX  = Self.boardW / 2
        self.ballPos  = CGPoint(x: Self.boardW / 2, y: Self.paddleY - 40)
        self.ballVel  = Self.initialVelocity(difficulty)
    }

    func reset() {
        stopTimer()
        bricks  = Self.freshBricks(rows: difficulty.breakoutBrickRows)
        paddleX = Self.boardW / 2
        ballPos = CGPoint(x: Self.boardW / 2, y: Self.paddleY - 40)
        ballVel = Self.initialVelocity(difficulty)
        lives = 3
        displaySeconds = 0
        finalMilliseconds = 0
        startDate = nil
        state = .idle
    }

    // MARK: - Input

    func movePaddle(to x: CGFloat) {
        paddleX = min(max(x, paddleW / 2), Self.boardW - paddleW / 2)
    }

    func startIfNeeded() {
        guard state == .idle else { return }
        state = .playing
        let now = Date()
        lastTick = now
        if startDate == nil { startDate = now }
        let t = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Game loop

    private func tick() {
        guard state == .playing else { return }
        let now = Date()
        let dt = CGFloat(min(now.timeIntervalSince(lastTick ?? now), 1.0 / 30))
        lastTick = now
        if let start = startDate {
            displaySeconds = Int(now.timeIntervalSince(start))
        }
        step(dt: dt)
    }

    private func step(dt: CGFloat) {
        var pos = CGPoint(x: ballPos.x + ballVel.x * dt,
                          y: ballPos.y + ballVel.y * dt)
        var vel = ballVel

        // Side walls
        if pos.x - Self.ballR < 0 {
            pos.x = Self.ballR; vel.x = abs(vel.x)
        }
        if pos.x + Self.ballR > Self.boardW {
            pos.x = Self.boardW - Self.ballR; vel.x = -abs(vel.x)
        }
        // Top wall
        if pos.y - Self.ballR < 0 {
            pos.y = Self.ballR; vel.y = abs(vel.y)
        }

        // Paddle
        let pLeft  = paddleX - paddleW / 2
        let pRight = paddleX + paddleW / 2
        let pTop   = Self.paddleY - Self.paddleH / 2
        if vel.y > 0,
           pos.y + Self.ballR >= pTop,
           pos.y - Self.ballR <= pTop + Self.paddleH,
           pos.x >= pLeft, pos.x <= pRight {
            pos.y = pTop - Self.ballR
            let hit = (pos.x - paddleX) / (paddleW / 2)   // -1…1
            let angle = hit * (.pi / 3)
            let speed = hypot(vel.x, vel.y)
            vel.x = speed * sin(angle)
            vel.y = -speed * abs(cos(angle))
        }

        // Bricks
        let bW = Self.brickW
        outer: for row in 0..<brickRows {
            for col in 0..<Self.brickCols {
                guard bricks[row][col] else { continue }
                let bx = Self.brickMargin + CGFloat(col) * (bW + Self.brickGap)
                let by = Self.brickStartY + CGFloat(row) * (Self.brickH + Self.brickGap)
                let br = CGRect(x: bx, y: by, width: bW, height: Self.brickH)
                guard pos.x + Self.ballR > br.minX,
                      pos.x - Self.ballR < br.maxX,
                      pos.y + Self.ballR > br.minY,
                      pos.y - Self.ballR < br.maxY else { continue }

                bricks[row][col] = false
                score += (brickRows - row) * 10

                let prevPos = CGPoint(x: pos.x - vel.x * dt, y: pos.y - vel.y * dt)
                let fromSide = prevPos.x + Self.ballR <= br.minX || prevPos.x - Self.ballR >= br.maxX
                if fromSide { vel.x = -vel.x } else { vel.y = -vel.y }
                break outer
            }
        }

        // Ball lost
        if pos.y - Self.ballR > Self.boardH {
            lives -= 1
            if lives <= 0 {
                state = .over
                stopTimer()
            } else {
                state = .idle
                stopTimer()
                pos  = CGPoint(x: Self.boardW / 2, y: Self.paddleY - 40)
                vel  = Self.initialVelocity(difficulty)
            }
        }

        // Win
        if bricks.allSatisfy({ $0.allSatisfy { !$0 } }) {
            if let start = startDate {
                finalMilliseconds = Int(Date().timeIntervalSince(start) * 1000)
            }
            state = .won
            stopTimer()
        }

        ballPos = pos
        ballVel = vel
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stopTimer() }

    // MARK: - Helpers

    private static func freshBricks(rows: Int) -> [[Bool]] {
        Array(repeating: Array(repeating: true, count: brickCols), count: rows)
    }

    private static func initialVelocity(_ difficulty: Difficulty) -> CGPoint {
        let s = difficulty.breakoutBallSpeed
        return CGPoint(x: s * 0.55, y: -s * 0.835)
    }
}

// MARK: - Difficulty extensions

extension Difficulty {
    var breakoutBallSpeed: CGFloat {
        switch self { case .easy: return 210; case .medium: return 290; case .hard: return 380 }
    }
    var breakoutPaddleW: CGFloat {
        switch self { case .easy: return 110; case .medium: return 85; case .hard: return 65 }
    }
    var breakoutBrickRows: Int {
        switch self { case .easy: return 4; case .medium: return 6; case .hard: return 8 }
    }
}
