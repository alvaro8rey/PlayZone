import SwiftUI

struct MastermindView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: MastermindGame
    @State private var showResult = false
    @State private var isNewRecord = false
    @State private var showInfo = false
    @State private var navigatedToRanking = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    private var pegSize: CGFloat { game.codeLength == 5 ? 34 : 40 }
    private var potentialScore: Int { (game.maxAttempts - game.rows.count) * 10000 - game.elapsedSeconds }

    private func formattedTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: MastermindGame(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 0) {
                statsRow
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                boardScroll

                colorPalette
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                actionRow
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
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
        .navigationTitle("Mastermind · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .mastermind) }
        .onChange(of: game.state) { _, st in
            if st == .won || st == .lost {
                Task {
                    if st == .won { await submitScore() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showResult = true }
                }
            }
        }
        .alert(game.state == .won ? "¡Lo conseguiste! 🎉" : "Has perdido 😔",
               isPresented: $showResult) {
            Button("Nuevo juego") { game.reset() }
            if game.state == .won {
                Button("Ver Ranking") {
                    navigatedToRanking = true
                    path.append(Route.ranking(.mastermind))
                }
            }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        } message: {
            if game.state == .won {
                Text(isNewRecord
                     ? "🏆 ¡Nuevo récord!  \(game.rows.count) intentos · \(formattedTime(game.elapsedSeconds))"
                     : "Resuelta en \(game.rows.count) intentos · \(formattedTime(game.elapsedSeconds))")
            } else {
                Text("La clave era: " + game.secret.map { $0.emoji }.joined())
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Intento").font(.caption.bold()).foregroundStyle(Color(hex: "94A3B8"))
                Text("\(game.rows.count + (game.state == .playing ? 1 : 0)) / \(game.maxAttempts)")
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(.white)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Tiempo").font(.caption.bold()).foregroundStyle(Color(hex: "94A3B8"))
                Text(formattedTime(game.elapsedSeconds))
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(.white)
            }
            Spacer()
            if game.state == .playing {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Máx. ahora").font(.caption.bold()).foregroundStyle(Color(hex: "94A3B8"))
                    Text("\(potentialScore)")
                        .font(.headline.bold().monospacedDigit())
                        .foregroundStyle(Color(hex: "EC4899"))
                }
            }
            Button { game.reset() } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2).foregroundStyle(.white).padding(.leading, 12)
            }
        }
    }

    // MARK: - Board

    private var boardScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 6) {
                    legendRow
                        .padding(.bottom, 4)
                    ForEach(0..<game.maxAttempts, id: \.self) { i in
                        boardRow(index: i)
                            .id(i)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: game.rows.count) { _, count in
                withAnimation {
                    proxy.scrollTo(min(count, game.maxAttempts - 1), anchor: .center)
                }
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 20) {
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "F1F5F9")).frame(width: 12, height: 12)
                Text("Posición correcta").font(.caption2).foregroundStyle(Color(hex: "94A3B8"))
            }
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "F59E0B")).frame(width: 12, height: 12)
                Text("Color correcto").font(.caption2).foregroundStyle(Color(hex: "94A3B8"))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func boardRow(index: Int) -> some View {
        let isPast    = index < game.rows.count
        let isCurrent = index == game.rows.count && game.state == .playing
        let pegs: [PegColor?] = isPast
            ? game.rows[index].pegs
            : (isCurrent ? game.current : Array(repeating: nil, count: game.codeLength))
        let blacks = isPast ? game.rows[index].blacks : 0
        let whites = isPast ? game.rows[index].whites : 0

        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption2.bold())
                .foregroundStyle(Color(hex: "475569"))
                .frame(width: 16)

            HStack(spacing: 8) {
                ForEach(0..<game.codeLength, id: \.self) { i in
                    let fillColor: Color = pegs[i].map { $0.color } ?? Color(hex: "1E293B")
                    Circle()
                        .fill(fillColor)
                        .overlay(
                            Circle().stroke(
                                isCurrent && pegs[i] == nil ? Color(hex: "334155") : Color.clear,
                                lineWidth: 1.5
                            )
                        )
                        .overlay(
                            isCurrent && pegs[i] != nil
                                ? Circle().stroke(.white.opacity(0.3), lineWidth: 1.5)
                                : nil
                        )
                        .frame(width: pegSize, height: pegSize)
                        .opacity(isPast || isCurrent ? 1 : 0.2)
                        .scaleEffect(isCurrent && pegs[i] != nil ? 1.0 : (isCurrent ? 0.88 : 1.0))
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pegs[i] != nil)
                        .onTapGesture {
                            if isCurrent { game.removePeg(at: i) }
                        }
                }
            }

            Spacer()

            feedbackDots(blacks: blacks, whites: whites, total: game.codeLength)
                .opacity(isPast ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? Color(hex: "1E293B") : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrent ? Color(hex: "EC4899").opacity(0.5) : Color.clear,
                                lineWidth: 1)
                )
        )
    }

    private func feedbackDots(blacks: Int, whites: Int, total: Int) -> some View {
        let colors: [Color] = (0..<total).map { i in
            if i < blacks          { return Color(hex: "F1F5F9") }
            if i < blacks + whites { return Color(hex: "F59E0B") }
            return Color(hex: "1E293B")
        }
        return LazyVGrid(
            columns: [GridItem(.fixed(14)), GridItem(.fixed(14))],
            spacing: 4
        ) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(colors[i])
                    .overlay(Circle().stroke(Color(hex: "475569"), lineWidth: 0.5))
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 36)
    }

    // MARK: - Color Palette

    private var colorPalette: some View {
        HStack(spacing: 0) {
            ForEach(PegColor.allCases, id: \.rawValue) { peg in
                Button {
                    game.tapColor(peg)
                } label: {
                    Circle()
                        .fill(peg.color)
                        .frame(width: 44, height: 44)
                        .shadow(color: peg.color.opacity(0.5), radius: 6)
                }
                .disabled(game.state != .playing)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                if let idx = game.current.indices.last(where: { game.current[$0] != nil }) {
                    game.removePeg(at: idx)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "delete.left.fill")
                    Text("Borrar")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(hex: "1E293B"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(game.state != .playing || game.current.allSatisfy { $0 == nil })

            Button { game.submit() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirmar")
                }
                .font(.subheadline.bold())
                .foregroundStyle(game.canSubmit ? .black : Color(hex: "94A3B8"))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(game.canSubmit ? Color.white : Color(hex: "1E293B"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!game.canSubmit)
        }
    }

    // MARK: - Submit score

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .mastermind, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .mastermind,
                                 difficulty: difficulty, value: game.score)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.score > previousBest!
    }
}
