import SwiftUI

struct FifteenPuzzleView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: FifteenPuzzleGame
    @State private var showResult  = false
    @State private var isNewRecord = false
    @State private var showInfo            = false
    @State private var navigatedToRanking  = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path      = path
        self._game      = State(initialValue: FifteenPuzzleGame(difficulty: difficulty))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 16) {
                hud
                GeometryReader { geo in
                    puzzleGrid(in: geo.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .overlay {
            if navigatedToRanking {
                PostRankingOverlay(
                    onNewGame: { navigatedToRanking = false; game.reset() },
                    onMenu:    { navigatedToRanking = false; path.removeLast(path.count) }
                )
            }
        }
        .navigationTitle("Puzzle \(game.size * game.size - 1) · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .puzzle15) }
        .onChange(of: game.isComplete) { _, complete in
            if complete {
                Task {
                    await submitScore()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showResult = true }
                }
            }
        }
        .alert("¡Puzzle completado! 🎉", isPresented: $showResult) {
            Button("Nuevo juego") { game.reset() }
            Button("Ver Ranking") { navigatedToRanking = true; path.append(Route.ranking(.puzzle15)) }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nuevo récord! \(formattedTime(game.elapsedSeconds))"
                 : "Tiempo: \(formattedTime(game.elapsedSeconds))")
        }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(Color(hex: "94A3B8"))
            Text(formattedTime(game.elapsedSeconds))
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(.white)
            Spacer()
            Text("\(game.moves) mov.")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color(hex: "94A3B8"))
            Spacer()
            Button { game.reset() } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private func puzzleGrid(in available: CGSize) -> some View {
        let n       = game.size
        let spacing = CGFloat(n <= 3 ? 8 : 6)
        let cs      = min(
            (available.width  - spacing * CGFloat(n - 1)) / CGFloat(n),
            (available.height - spacing * CGFloat(n - 1)) / CGFloat(n)
        )
        let fontSize: CGFloat = n <= 3 ? 32 : n <= 4 ? 24 : 18

        VStack(spacing: spacing) {
            ForEach(0..<n, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<n, id: \.self) { col in
                        let index   = row * n + col
                        let tile    = game.tiles[index]
                        let inPlace = tile != 0 && tile == index + 1

                        ZStack {
                            if tile == 0 {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "0F172A"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(hex: "1E293B"), lineWidth: 2)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(inPlace
                                          ? Color(hex: "06B6D4").opacity(0.2)
                                          : Color(hex: "1E293B"))
                                Text("\(tile)")
                                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(inPlace ? Color(hex: "06B6D4") : .white)
                            }
                        }
                        .frame(width: cs, height: cs)
                        .onTapGesture { game.tap(index: index) }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func submitScore() async {
        let current      = try? await rankingService.fetch(game: .puzzle15, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .puzzle15,
                                 difficulty: difficulty, value: game.finalMilliseconds)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.finalMilliseconds < previousBest!
    }
}
