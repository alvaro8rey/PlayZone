import SwiftUI

struct MemoryView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: MemoryGame
    @State private var showResult = false
    @State private var isNewRecord = false
    @State private var showInfo            = false
    @State private var navigatedToRanking  = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: MemoryGame(difficulty: difficulty))
    }

    private var columns: Int {
        switch difficulty {
        case .easy:   return 3
        case .medium: return 4
        case .hard:   return 5
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1A0533"), Color(hex: "0F172A")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                statsRow
                cardsGrid
                Spacer()
            }
            .padding(.top, 8)
        }
        .overlay {
            if navigatedToRanking {
                PostRankingOverlay(
                    onNewGame: { navigatedToRanking = false; game.reset() },
                    onMenu:    { navigatedToRanking = false; path.removeLast(path.count) }
                )
            }
        }
        .navigationTitle("Memoria · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .memory) }
        .onChange(of: game.isComplete) { _, complete in
            if complete {
                Task {
                    await submitScore()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showResult = true }
                }
            }
        }
        .alert("¡Completado! 🎉", isPresented: $showResult) {
            Button("Nuevo juego") { game.reset() }
            Button("Ver Ranking") { navigatedToRanking = true; path.append(Route.ranking(.memory)) }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nuevo récord!  \(formattedTime(game.elapsedSeconds))  •  \(game.moves) movs."
                 : "Tiempo: \(formattedTime(game.elapsedSeconds))  •  \(game.moves) movs.")
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack {
            statBox(title: "Parejas", value: "\(game.matchedPairs)/\(game.totalPairs)")
            statBox(title: "Tiempo", value: formattedTime(game.elapsedSeconds))
            statBox(title: "Movs.", value: "\(game.moves)")
            Button { game.reset() } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption.bold()).foregroundStyle(Color(hex: "94A3B8"))
            Text(value).font(.headline.bold().monospacedDigit()).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Cards Grid

    private var cardsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(game.cards) { card in
                MemoryCardView(card: card)
                    .onTapGesture { game.tap(card: card) }
            }
        }
        .padding(.horizontal, 16)
    }

    private func formattedTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .memory, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .memory,
                                 difficulty: difficulty, value: game.finalMilliseconds)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.finalMilliseconds < previousBest!
    }
}

// MARK: - Card View

struct MemoryCardView: View {
    let card: MemoryCard

    var body: some View {
        ZStack {
            if card.isFaceUp || card.isMatched {
                RoundedRectangle(cornerRadius: 12)
                    .fill(card.isMatched
                          ? LinearGradient(colors: [Color(hex: "6D28D9"), Color(hex: "A855F7")], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color(hex: "4C1D95"), Color(hex: "7C3AED")], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(card.emoji)
                    .font(.system(size: 32))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(hex: "1E293B"), Color(hex: "334155")], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "questionmark")
                    .font(.title2.bold())
                    .foregroundStyle(Color(hex: "475569"))
            }
        }
        .aspectRatio(0.8, contentMode: .fit)
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .rotation3DEffect(.degrees(card.isFaceUp || card.isMatched ? 0 : 180), axis: (0, 1, 0))
        .animation(.spring(response: 0.4), value: card.isFaceUp)
        .scaleEffect(card.isMatched ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: card.isMatched)
    }
}
