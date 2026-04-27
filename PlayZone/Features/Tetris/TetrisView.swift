import SwiftUI

struct TetrisView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: TetrisGame
    @State private var showOver = false
    @State private var isNewRecord = false
    @State private var showInfo = false
    @State private var navigatedToRanking = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: TetrisGame(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    boardView
                    sidePanel
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                controlPad
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            if game.state == .idle {
                startOverlay
            }
        }
        .background(SwipeBackDisabler())
        .overlay {
            if navigatedToRanking {
                PostRankingOverlay(
                    onNewGame: { navigatedToRanking = false; game.reset() },
                    onMenu:    { navigatedToRanking = false; path.removeLast(path.count) }
                )
            }
        }
        .navigationTitle("Tetris · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .tetris) }
        .onChange(of: game.state) { _, st in
            if st == .over {
                Task {
                    await submitScore()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showOver = true }
                }
            }
        }
        .alert("Game Over 🧱", isPresented: $showOver) {
            Button("Reintentar") { game.reset() }
            Button("Ver Ranking") { navigatedToRanking = true; path.append(Route.ranking(.tetris)) }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nueva marca!  \(game.score) pts"
                 : "Puntuación: \(game.score) pts")
        }
    }

    // MARK: - Board

    private var boardView: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / CGFloat(TetrisGame.cols)
            let boardH = cellSize * CGFloat(TetrisGame.rows)
            Canvas { ctx, _ in
                drawBoard(ctx: ctx, cellSize: cellSize)
            }
            .frame(width: geo.size.width, height: boardH)
            .background(Color(hex: "0F2027"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "334155"), lineWidth: 1))
        }
        .aspectRatio(CGFloat(TetrisGame.cols) / CGFloat(TetrisGame.rows), contentMode: .fit)
    }

    private func drawBoard(ctx: GraphicsContext, cellSize: CGFloat) {
        // Grid lines
        for r in 0...TetrisGame.rows {
            let y = CGFloat(r) * cellSize
            var path = Path(); path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: cellSize * CGFloat(TetrisGame.cols), y: y))
            ctx.stroke(path, with: .color(Color(hex: "1E293B").opacity(0.5)), lineWidth: 0.5)
        }
        for c in 0...TetrisGame.cols {
            let x = CGFloat(c) * cellSize
            var path = Path(); path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: cellSize * CGFloat(TetrisGame.rows)))
            ctx.stroke(path, with: .color(Color(hex: "1E293B").opacity(0.5)), lineWidth: 0.5)
        }

        // Locked cells
        for r in 0..<TetrisGame.rows {
            for c in 0..<TetrisGame.cols {
                let cell = game.board[r][c]
                if cell.filled {
                    drawCell(ctx: ctx, row: r, col: c, color: cell.color, cellSize: cellSize)
                }
            }
        }

        // Ghost piece
        if let p = game.current {
            let ghostR = game.ghostRow
            if ghostR != p.row {
                for r in 0..<p.cells.count {
                    for c in 0..<p.cells[r].count {
                        guard p.cells[r][c] else { continue }
                        drawCell(ctx: ctx, row: ghostR + r, col: p.col + c, color: p.color.opacity(0.25), cellSize: cellSize, inset: 3)
                    }
                }
            }
        }

        // Current piece
        if let p = game.current {
            for r in 0..<p.cells.count {
                for c in 0..<p.cells[r].count {
                    guard p.cells[r][c] else { continue }
                    drawCell(ctx: ctx, row: p.row + r, col: p.col + c, color: p.color, cellSize: cellSize)
                }
            }
        }
    }

    private func drawCell(ctx: GraphicsContext, row: Int, col: Int, color: Color, cellSize: CGFloat, inset: CGFloat = 1) {
        let rect = CGRect(x: CGFloat(col) * cellSize + inset,
                          y: CGFloat(row) * cellSize + inset,
                          width: cellSize - inset * 2,
                          height: cellSize - inset * 2)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
        // Highlight top-left edge
        var highlight = Path()
        highlight.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        highlight.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        highlight.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        ctx.stroke(highlight, with: .color(.white.opacity(0.3)), lineWidth: 1)
    }

    // MARK: - Side Panel

    private var sidePanel: some View {
        VStack(spacing: 12) {
            statBox(title: "PUNTOS", value: "\(game.score)")
            statBox(title: "LÍNEAS", value: "\(game.lines)")
            statBox(title: "NIVEL",  value: "\(game.level)")
            nextPieceBox
            holdBox
            Spacer()
        }
        .frame(width: 80)
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(Color(hex: "94A3B8"))
            Text(value).font(.system(size: 18, weight: .bold).monospacedDigit()).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var nextPieceBox: some View {
        VStack(spacing: 4) {
            Text("NEXT").font(.system(size: 9, weight: .bold)).foregroundStyle(Color(hex: "94A3B8"))
            Canvas { ctx, size in
                let cellSize: CGFloat = 14
                let cells = game.next.cells
                let pieceW = CGFloat(cells[0].count) * cellSize
                let pieceH = CGFloat(cells.count) * cellSize
                let offsetX = (size.width - pieceW) / 2
                let offsetY = (size.height - pieceH) / 2
                for r in 0..<cells.count {
                    for c in 0..<cells[r].count {
                        guard cells[r][c] else { continue }
                        let rect = CGRect(x: offsetX + CGFloat(c) * cellSize + 1,
                                         y: offsetY + CGFloat(r) * cellSize + 1,
                                         width: cellSize - 2, height: cellSize - 2)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(game.next.color))
                    }
                }
            }
            .frame(width: 70, height: 50)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var holdBox: some View {
        VStack(spacing: 4) {
            Text("HOLD").font(.system(size: 9, weight: .bold)).foregroundStyle(Color(hex: "94A3B8"))
            Canvas { ctx, size in
                guard let type = game.held else { return }
                let cellSize: CGFloat = 14
                let cells = type.cells
                let pieceW = CGFloat(cells[0].count) * cellSize
                let pieceH = CGFloat(cells.count) * cellSize
                let offsetX = (size.width - pieceW) / 2
                let offsetY = (size.height - pieceH) / 2
                let alpha: CGFloat = game.canHold ? 1.0 : 0.4
                for r in 0..<cells.count {
                    for c in 0..<cells[r].count {
                        guard cells[r][c] else { continue }
                        let rect = CGRect(x: offsetX + CGFloat(c) * cellSize + 1,
                                         y: offsetY + CGFloat(r) * cellSize + 1,
                                         width: cellSize - 2, height: cellSize - 2)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(type.color.opacity(alpha)))
                    }
                }
            }
            .frame(width: 70, height: 50)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Controls

    private var controlPad: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                controlBtn("arrow.left", wide: false) { game.moveLeft() }
                controlBtn("arrow.clockwise", wide: false) { game.rotate() }
                controlBtn("arrow.down", wide: false) { game.softDrop() }
                controlBtn("arrow.right", wide: false) { game.moveRight() }
            }
            HStack(spacing: 10) {
                controlBtn("tray.and.arrow.down.fill", wide: true, disabled: !game.canHold) { game.holdPiece() }
                controlBtn("arrow.down.to.line", wide: true) { game.hardDrop() }
            }
        }
    }

    private func controlBtn(_ icon: String, wide: Bool, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(disabled ? Color(hex: "475569") : .white)
                .frame(minWidth: 64, maxWidth: wide ? .infinity : nil, minHeight: 52)
                .background(Color(hex: "1E293B"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(disabled)
    }

    // MARK: - Start Overlay

    private var startOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: "A855F7"))
            Text("Toca para empezar")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { game.start() }
    }

    // MARK: - Score submit

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .tetris, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .tetris,
                                 difficulty: difficulty, value: game.score)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.score > previousBest!
    }
}
