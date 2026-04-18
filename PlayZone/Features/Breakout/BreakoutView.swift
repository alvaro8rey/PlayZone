import SwiftUI

struct BreakoutView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: BreakoutGame
    @State private var showOver  = false
    @State private var showWin   = false
    @State private var isNewRecord = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: BreakoutGame(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()
            VStack(spacing: 8) {
                hud
                board
            }
            .padding(.top, 8)
        }
        .navigationTitle("Breakout · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .background(SwipeBackDisabler())
        .onChange(of: game.state) { _, st in
            guard st != .playing, st != .idle else { return }
            Task {
                if st == .won || st == .over { await submitScore() }
                try? await Task.sleep(nanoseconds: 600_000_000)
                if st == .won  { showWin  = true }
                if st == .over { showOver = true }
            }
        }
        .alert("¡Ganaste! 🎉", isPresented: $showWin) {
            Button("Nuevo juego") { game.reset() }
            Button("Menú") { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nueva marca!  \(game.score) pts"
                 : "Puntuación: \(game.score) pts")
        }
        .alert("Game Over", isPresented: $showOver) {
            Button("Reintentar") { game.reset() }
            Button("Menú") { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nueva marca!  \(game.score) pts"
                 : "Puntuación: \(game.score) pts")
        }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack {
            Label("\(game.score)", systemImage: "star.fill")
                .font(.headline.bold())
                .foregroundStyle(.yellow)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < game.lives ? "heart.fill" : "heart")
                        .foregroundStyle(i < game.lives ? Color(hex: "EF4444") : Color(hex: "475569"))
                        .font(.subheadline)
                }
            }
            Spacer()
            Button { game.reset() } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Board

    private var board: some View {
        GeometryReader { geo in
            let s = geo.size.width / BreakoutGame.boardW
            ZStack {
                Canvas { ctx, _ in draw(ctx: ctx, scale: s) }
                    .frame(width: BreakoutGame.boardW * s,
                           height: BreakoutGame.boardH * s)

                if game.state == .idle {
                    idleOverlay
                }
            }
            .frame(width: geo.size.width, height: BreakoutGame.boardH * s, alignment: .top)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        game.movePaddle(to: val.location.x / s)
                        game.startIfNeeded()
                    }
            )
        }
        .aspectRatio(BreakoutGame.boardW / BreakoutGame.boardH, contentMode: .fit)
    }

    // MARK: - Canvas drawing

    private func draw(ctx: GraphicsContext, scale s: CGFloat) {
        let bW = BreakoutGame.brickW
        let bH = BreakoutGame.brickH
        let margin = BreakoutGame.brickMargin
        let gap    = BreakoutGame.brickGap
        let startY = BreakoutGame.brickStartY

        // Board background
        ctx.fill(Path(CGRect(x: 0, y: 0,
                             width: BreakoutGame.boardW * s,
                             height: BreakoutGame.boardH * s)),
                 with: .color(Color(hex: "0F2027")))

        // Bricks
        for row in 0..<game.brickRows {
            for col in 0..<BreakoutGame.brickCols {
                guard game.bricks[row][col] else { continue }
                let x = (margin + CGFloat(col) * (bW + gap)) * s
                let y = (startY + CGFloat(row) * (bH + gap)) * s
                let rect = CGRect(x: x, y: y, width: bW * s, height: bH * s)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3),
                         with: .color(brickColor(row: row)))
            }
        }

        // Paddle
        let px = (game.paddleX - game.paddleW / 2) * s
        let py = (BreakoutGame.paddleY - BreakoutGame.paddleH / 2) * s
        let paddleRect = CGRect(x: px, y: py,
                                width: game.paddleW * s,
                                height: BreakoutGame.paddleH * s)
        ctx.fill(Path(roundedRect: paddleRect, cornerRadius: 6),
                 with: .color(.white))

        // Ball
        let br = BreakoutGame.ballR * s
        let ballRect = CGRect(x: game.ballPos.x * s - br,
                              y: game.ballPos.y * s - br,
                              width: br * 2, height: br * 2)
        ctx.fill(Path(ellipseIn: ballRect), with: .color(.white))
    }

    private func brickColor(row: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "EF4444"),
            Color(hex: "F97316"),
            Color(hex: "EAB308"),
            Color(hex: "22C55E"),
            Color(hex: "14B8A6"),
            Color(hex: "3B82F6"),
            Color(hex: "A855F7"),
            Color(hex: "EC4899"),
        ]
        return colors[row % colors.count]
    }

    // MARK: - Idle overlay

    private var idleOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color(hex: "EC4899"))
            Text("Arrastra para mover\ny lanzar la pelota")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Submit score

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .breakout, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .breakout,
                                 difficulty: difficulty, value: game.score)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.score > previousBest!
    }
}

