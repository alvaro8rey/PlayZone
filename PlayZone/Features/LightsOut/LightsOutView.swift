import SwiftUI

struct LightsOutView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: LightsOutGame
    @State private var showResult  = false
    @State private var isNewRecord = false
    @State private var showInfo            = false
    @State private var navigatedToRanking  = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path      = path
        self._game      = State(initialValue: LightsOutGame(difficulty: difficulty))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 20) {
                hud
                GeometryReader { geo in
                    lightsGrid(in: geo.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .overlay {
            if navigatedToRanking {
                PostRankingOverlay(
                    onNewGame: { navigatedToRanking = false; game.reset() },
                    onMenu:    { navigatedToRanking = false; path.removeLast(path.count) }
                )
            }
        }
        .navigationTitle("Lights Out · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .lightsOut) }
        .onChange(of: game.isComplete) { _, complete in
            if complete {
                Task {
                    await submitScore()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showResult = true }
                }
            }
        }
        .alert("¡Todas las luces apagadas! 🎉", isPresented: $showResult) {
            Button("Nuevo juego") { game.reset() }
            Button("Ver Ranking") { navigatedToRanking = true; path.append(Route.ranking(.lightsOut)) }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nuevo récord! \(game.moves) movimientos"
                 : "\(game.moves) movimientos")
        }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack {
            Image(systemName: "hand.tap.fill")
                .foregroundStyle(Color(hex: "94A3B8"))
            Text("\(game.moves) movimientos")
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

    // MARK: - Grid

    @ViewBuilder
    private func lightsGrid(in available: CGSize) -> some View {
        let n       = game.size
        let spacing = CGFloat(n <= 3 ? 10 : n <= 5 ? 8 : 6)
        let cs      = min(
            (available.width  - spacing * CGFloat(n - 1)) / CGFloat(n),
            (available.height - spacing * CGFloat(n - 1)) / CGFloat(n)
        )

        VStack(spacing: spacing) {
            ForEach(0..<n, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<n, id: \.self) { col in
                        let on = game.grid[row][col]
                        RoundedRectangle(cornerRadius: cs * 0.15)
                            .fill(on ? Color(hex: "FBBF24") : Color(hex: "1E293B"))
                            .frame(width: cs, height: cs)
                            .shadow(
                                color: on ? Color(hex: "FBBF24").opacity(0.55) : .clear,
                                radius: 10
                            )
                            .animation(.easeInOut(duration: 0.12), value: on)
                            .onTapGesture { game.tap(row, col) }
                    }
                }
            }
        }
    }

    // MARK: - Score

    private func submitScore() async {
        let current      = try? await rankingService.fetch(game: .lightsOut, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .lightsOut,
                                 difficulty: difficulty, value: game.moves)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.moves < previousBest!
    }
}
