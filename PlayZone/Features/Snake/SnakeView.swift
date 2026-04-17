import SwiftUI

struct SnakeView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: SnakeGame
    @State private var showOver = false
    @State private var isNewRecord = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: SnakeGame(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 12) {
                scoreRow
                boardView
                    .padding(.horizontal, 16)
                dpad
                    .padding(.horizontal, 48)
                    .padding(.bottom, 8)
            }
            .padding(.top, 8)

            if game.state == .idle {
                startOverlay
            }
        }
        .navigationTitle("Snake · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: game.state) { _, st in
            if st == .over {
                Task {
                    await submitScore()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showOver = true }
                }
            }
        }
        .alert("Game Over 🐍", isPresented: $showOver) {
            Button("Reintentar") { game.reset() }
            Button("Menú") { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nueva marca!  \(game.score) pts"
                 : "Puntuación: \(game.score) pts")
        }
    }

    // MARK: - Score Row

    private var scoreRow: some View {
        HStack {
            Label("\(game.score)", systemImage: "star.fill")
                .font(.headline.bold())
                .foregroundStyle(.yellow)
            Spacer()
            Text("Longitud: \(game.snake.count)")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "94A3B8"))
            Spacer()
            Button { game.reset() } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Board

    private var boardView: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let cell = side / CGFloat(game.gridSize)
            Canvas { ctx, _ in
                // Background
                ctx.fill(Path(CGRect(x: 0, y: 0, width: side, height: side)),
                         with: .color(Color(hex: "0F2027")))

                // Grid dots
                for r in 0..<game.gridSize {
                    for c in 0..<game.gridSize {
                        let rect = CGRect(x: CGFloat(c) * cell + cell * 0.4,
                                         y: CGFloat(r) * cell + cell * 0.4,
                                         width: cell * 0.2, height: cell * 0.2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: "1E293B")))
                    }
                }

                // Snake body
                for (i, point) in game.snake.enumerated() {
                    let inset: CGFloat = i == 0 ? 1 : 2
                    let rect = CGRect(x: CGFloat(point.col) * cell + inset,
                                     y: CGFloat(point.row) * cell + inset,
                                     width: cell - inset * 2, height: cell - inset * 2)
                    let color = i == 0 ? Color(hex: "4ADE80") : Color(hex: "16A34A")
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color))
                }

                // Food
                let fr = game.food
                let frect = CGRect(x: CGFloat(fr.col) * cell + 2,
                                   y: CGFloat(fr.row) * cell + 2,
                                   width: cell - 4, height: cell - 4)
                ctx.fill(Path(ellipseIn: frect), with: .color(Color(hex: "EF4444")))
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "334155"), lineWidth: 1))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - D-Pad

    private var dpad: some View {
        VStack(spacing: 6) {
            dpadButton("chevron.up") { game.changeDirection(.up); startIfNeeded() }
            HStack(spacing: 6) {
                dpadButton("chevron.left")  { game.changeDirection(.left);  startIfNeeded() }
                dpadButton("chevron.down")  { game.changeDirection(.down);  startIfNeeded() }
                dpadButton("chevron.right") { game.changeDirection(.right); startIfNeeded() }
            }
        }
    }

    private func dpadButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 68, height: 50)
                .background(Color(hex: "1E293B"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Start Overlay

    private var startOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: "14B8A6"))
            Text("Toca una flecha para\nempezar")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func startIfNeeded() {
        if game.state == .idle { game.start() }
    }

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .snake, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .snake,
                                 difficulty: difficulty, value: game.score)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.score > previousBest!
    }
}
