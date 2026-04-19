import SwiftUI

struct MinesweeperView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: MinesweeperGame
    @State private var showResult = false
    @State private var isNewRecord = false
    @State private var showInfo            = false
    @State private var navigatedToRanking  = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: MinesweeperGame(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 0) {
                statusBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider().background(Color(hex: "334155"))

                GeometryReader { geo in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        boardGrid(availableWidth: geo.size.width)
                            .padding(12)
                    }
                }
            }
        }
        .overlay {
            if navigatedToRanking {
                PostRankingOverlay(
                    onNewGame: { navigatedToRanking = false; game.reset() },
                    onMenu:    { navigatedToRanking = false; path.removeLast(path.count) }
                )
            }
        }
        .navigationTitle("Buscaminas · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .minesweeper) }
        .onChange(of: game.state) { _, newState in
            if newState == .won || newState == .lost {
                Task {
                    await submitScore()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showResult = true }
                }
            }
        }
        .alert(game.state == .won ? "¡Ganaste! 🎉" : "¡Boom! 💥", isPresented: $showResult) {
            Button("Reintentar") { game.reset() }
            Button("Ver Ranking") { navigatedToRanking = true; path.append(Route.ranking(.minesweeper)) }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        } message: {
            if game.state == .won {
                Text(isNewRecord
                     ? "🏆 ¡Nuevo récord! \(formattedTime(game.elapsedSeconds))"
                     : "Tiempo: \(formattedTime(game.elapsedSeconds))")
            } else {
                Text("Has explotado una mina.")
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Label("\(game.remainingMines)", systemImage: "flag.fill")
                .foregroundStyle(.red)
                .font(.headline.bold())

            Spacer()

            Text(formattedTime(game.elapsedSeconds))
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(.white)

            Spacer()

            Button { game.reset() } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Board

    private func boardGrid(availableWidth: CGFloat) -> some View {
        let cols = game.config.cols
        let cellSize: CGFloat = min(34, (availableWidth - 24) / CGFloat(cols))

        return VStack(spacing: 2) {
            ForEach(0..<game.config.rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<cols, id: \.self) { col in
                        let idx = game.index(row: row, col: col)
                        MineCellView(cell: game.cells[idx], size: cellSize)
                            .onTapGesture { game.reveal(index: idx) }
                            .onLongPressGesture { game.toggleFlag(index: idx) }
                    }
                }
            }
        }
    }

    private func formattedTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func submitScore() async {
        guard game.state == .won else { return }
        let current = try? await rankingService.fetch(game: .minesweeper, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .minesweeper,
                                 difficulty: difficulty, value: game.finalMilliseconds)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.finalMilliseconds < previousBest!
    }
}

// MARK: - Cell View

struct MineCellView: View {
    let cell: MineCell
    let size: CGFloat

    var body: some View {
        ZStack {
            if cell.isRevealed {
                RoundedRectangle(cornerRadius: 4)
                    .fill(cell.isMine ? Color.red.opacity(0.8) : Color(hex: "1E293B"))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "334155"), lineWidth: 0.5))

                if cell.isMine {
                    Text("💣").font(.system(size: size * 0.55))
                } else if cell.adjacentMines > 0 {
                    Text("\(cell.adjacentMines)")
                        .font(.system(size: size * 0.55, weight: .bold))
                        .foregroundStyle(numberColor(cell.adjacentMines))
                }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "334155"))

                if cell.isFlagged {
                    Text("🚩").font(.system(size: size * 0.55))
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func numberColor(_ n: Int) -> Color {
        switch n {
        case 1: return .blue
        case 2: return .green
        case 3: return .red
        case 4: return .purple
        case 5: return .orange
        default: return .cyan
        }
    }
}
