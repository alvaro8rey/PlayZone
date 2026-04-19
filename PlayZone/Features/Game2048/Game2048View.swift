import SwiftUI

struct Game2048View: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: Game2048
    @State private var showWin = false
    @State private var showOver = false
    @State private var isNewRecord = false
    @State private var showInfo = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: Game2048(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 20) {
                scoreRow
                goalLabel
                boardView
                    .padding(.horizontal, 16)
                controls
            }
            .padding(.top, 8)
        }
        .navigationTitle("2048 · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .game2048) }
        .background(
            SwipeCapture { dir in
                switch dir {
                case .up:    game.swipe(.up)
                case .down:  game.swipe(.down)
                case .left:  game.swipe(.left)
                case .right: game.swipe(.right)
                }
            }
        )
        .onChange(of: game.hasWon) { _, won in if won { showWin = true } }
        .onChange(of: game.isOver) { _, over in
            if over {
                Task {
                    await submitScore()
                    showOver = true
                }
            }
        }
        .alert("¡Llegaste a \(game.goal)! 🎉", isPresented: $showWin) {
            Button("Seguir jugando") { }
            Button("Nuevo juego") { game.reset() }
            Button("Ver Ranking") { path.append(Route.ranking(.game2048)) }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        }
        .alert("Game Over", isPresented: $showOver) {
            Button("Reintentar") { game.reset() }
            Button("Ver Ranking") { path.append(Route.ranking(.game2048)) }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nueva marca!  \(game.score) pts"
                 : "Puntuación: \(game.score) pts")
        }
    }

    // MARK: - Score Row

    private var scoreRow: some View {
        HStack(spacing: 16) {
            scoreBox(title: "PUNTOS", value: "\(game.score)")
            scoreBox(title: "MEJOR", value: "\(game.bestScore)")
            Button { game.reset() } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    private func scoreBox(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption.bold()).foregroundStyle(Color(hex: "94A3B8"))
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var goalLabel: some View {
        HStack {
            Image(systemName: "flag.fill").foregroundStyle(.yellow)
            Text("Meta: \(game.goal)").font(.subheadline.bold()).foregroundStyle(Color(hex: "94A3B8"))
        }
    }

    // MARK: - Board

    private var boardView: some View {
        GeometryReader { geo in
            let boardSize = geo.size.width
            let gap: CGFloat = 8
            // Guard against zero/negative during navigation transitions
            let cell = boardSize > 0
                ? (boardSize - gap * CGFloat(game.size + 1)) / CGFloat(game.size)
                : 0

            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: "334155"))

                if cell > 0 {
                    VStack(spacing: gap) {
                        ForEach(0..<game.size, id: \.self) { row in
                            HStack(spacing: gap) {
                                ForEach(0..<game.size, id: \.self) { col in
                                    Tile2048(value: game.board[row][col], size: cell)
                                }
                            }
                        }
                    }
                    .padding(gap)
                }
            }
            .frame(width: boardSize, height: boardSize)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            Button { game.swipe(.up) } label: { arrowButton("chevron.up") }
            HStack(spacing: 8) {
                Button { game.swipe(.left) }  label: { arrowButton("chevron.left") }
                Button { game.swipe(.down) }  label: { arrowButton("chevron.down") }
                Button { game.swipe(.right) } label: { arrowButton("chevron.right") }
            }
        }
    }

    private func arrowButton(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.title2.bold())
            .foregroundStyle(.white)
            .frame(width: 64, height: 48)
            .background(Color(hex: "1E293B"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .game2048, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .game2048,
                                 difficulty: difficulty, value: game.score)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.score > previousBest!
    }
}

// MARK: - Tile

struct Tile2048: View {
    let value: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(tileColor)
            if value > 0 {
                Text(value >= 1000 ? "\(value/1000)K" : "\(value)")
                    .font(.system(size: size * (value >= 1000 ? 0.32 : 0.42), weight: .bold))
                    .foregroundStyle(value <= 4 ? Color(hex: "776E65") : .white)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.2), value: value)
    }

    private var tileColor: Color {
        switch value {
        case 0:    return Color(hex: "475569")
        case 2:    return Color(hex: "EEE4DA")
        case 4:    return Color(hex: "EDE0C8")
        case 8:    return Color(hex: "F2B179")
        case 16:   return Color(hex: "F59563")
        case 32:   return Color(hex: "F67C5F")
        case 64:   return Color(hex: "F65E3B")
        case 128:  return Color(hex: "EDCF72")
        case 256:  return Color(hex: "EDCC61")
        case 512:  return Color(hex: "EDC850")
        case 1024: return Color(hex: "EDC53F")
        case 2048: return Color(hex: "EDC22E")
        default:   return Color(hex: "3C3A32")
        }
    }
}

