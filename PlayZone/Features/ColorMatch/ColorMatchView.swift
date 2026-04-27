import SwiftUI

struct ColorMatchView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: ColorMatchGame
    @State private var red:   Double = 127
    @State private var green: Double = 127
    @State private var blue:  Double = 127
    @State private var showSummary  = false
    @State private var isNewRecord  = false
    @State private var showInfo            = false
    @State private var navigatedToRanking  = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: ColorMatchGame(difficulty: difficulty))
    }

    // MARK: - Computed helpers

    private var guessColor: Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 20) {
                roundHeader
                colorSwatches

                if game.state == .playing {
                    slidersSection
                    Spacer()
                    confirmButton
                } else {
                    // .showingResult and .finished both keep the last result visible;
                    // the summary sheet appears on top when .finished, so nothing flickers.
                    resultSection
                    Spacer()
                    if game.state == .showingResult {
                        nextButton
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
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
        .navigationTitle("Color Mix · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .colorMatch) }
        .sheet(isPresented: $showSummary) {
            ColorMatchSummarySheet(
                game: game,
                isNewRecord: isNewRecord,
                onNewGame: { showSummary = false; game.reset() },
                onRanking: { showSummary = false; navigatedToRanking = true; path.append(Route.ranking(.colorMatch)) },
                onMenu:    { showSummary = false; path.removeLast(path.count) }
            )
        }
        .onChange(of: game.state) { _, st in
            if st == .playing {
                red = 127; green = 127; blue = 127
            }
            if st == .finished {
                Task {
                    await submitScore()
                    showSummary = true
                }
            }
        }
    }

    // MARK: - Round header

    private var roundHeader: some View {
        HStack {
            Text("Ronda \(game.currentIndex + 1) de \(game.rounds.count)")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Text("\(game.totalScore) pts")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color(hex: "94A3B8"))
        }
    }

    // MARK: - Color swatches

    private var colorSwatches: some View {
        HStack(spacing: 16) {
            swatch(color: game.currentRound.targetColor, label: "Objetivo")
            swatch(color: guessColor,                    label: "Tu mezcla")
        }
    }

    private func swatch(color: Color, label: String) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 16)
                .fill(color)
                .frame(height: 110)
                .shadow(color: color.opacity(0.5), radius: 8, y: 4)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(Color(hex: "94A3B8"))
        }
    }

    // MARK: - Sliders

    private var slidersSection: some View {
        VStack(spacing: 14) {
            colorSlider(label: "R", value: $red,   accent: Color(hex: "EF4444"))
            colorSlider(label: "G", value: $green, accent: Color(hex: "22C55E"))
            colorSlider(label: "B", value: $blue,  accent: Color(hex: "3B82F6"))
        }
        .padding(16)
        .background(Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func colorSlider(label: String, value: Binding<Double>, accent: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.headline.bold())
                .foregroundStyle(accent)
                .frame(width: 18)
            Slider(value: value, in: 0...255)
                .tint(accent)
            Text(String(format: "%3d", Int(value.wrappedValue)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 30)
        }
    }

    // MARK: - Confirm button

    private var confirmButton: some View {
        Button { game.confirmGuess(r: red, g: green, b: blue) } label: {
            Text("Confirmar")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "6366F1"))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Result section

    private var resultSection: some View {
        let score = game.currentRound.score ?? 0
        let round = game.currentRound
        return VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(score))
                    .contentTransition(.numericText())
                Text("/ 100 puntos")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "94A3B8"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(hex: "1E293B"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 10) {
                deltaRow(label: "R", target: round.targetR, guess: red,   accent: Color(hex: "EF4444"))
                deltaRow(label: "G", target: round.targetG, guess: green, accent: Color(hex: "22C55E"))
                deltaRow(label: "B", target: round.targetB, guess: blue,  accent: Color(hex: "3B82F6"))
            }
            .padding(14)
            .background(Color(hex: "1E293B"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func deltaRow(label: String, target: Double, guess: Double, accent: Color) -> some View {
        let delta = abs(Int(target) - Int(guess))
        return HStack(spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(accent)
                .frame(width: 18)
            Text("Obj: \(Int(target))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
            Spacer()
            Text("Tuyo: \(Int(guess))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color(hex: "94A3B8"))
            Text("Δ\(delta)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(delta < 15 ? Color(hex: "22C55E") : delta < 40 ? Color(hex: "EAB308") : Color(hex: "EF4444"))
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Next button

    private var nextButton: some View {
        let isLast = game.currentIndex + 1 >= game.rounds.count
        return Button { game.nextRound() } label: {
            Text(isLast ? "Ver resultado final" : "Siguiente ronda")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "6366F1"))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ pct: Int) -> Color {
        if pct >= 90 { return Color(hex: "22C55E") }
        if pct >= 70 { return Color(hex: "EAB308") }
        return Color(hex: "EF4444")
    }

    private func submitScore() async {
        let total = game.totalScore
        guard total > 0 else { return }
        let current = try? await rankingService.fetch(game: .colorMatch, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .colorMatch,
                                 difficulty: difficulty, value: total)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || total > previousBest!
    }
}

// MARK: - Summary sheet

struct ColorMatchSummarySheet: View {
    let game:        ColorMatchGame
    let isNewRecord: Bool
    let onNewGame:   () -> Void
    let onRanking:   () -> Void
    let onMenu:      () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Total score header
                    VStack(spacing: 4) {
                        if isNewRecord {
                            Text("🏆 ¡Nuevo récord!")
                                .font(.headline.bold())
                                .foregroundStyle(Color(hex: "EAB308"))
                        }
                        Text("\(game.totalScore) / \(game.maxScore) pts")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(game.totalScore, max: game.maxScore))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Per-round breakdown
                    VStack(spacing: 10) {
                        ForEach(Array(game.rounds.enumerated()), id: \.offset) { i, round in
                            roundRow(index: i, round: round)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Resumen · Color Mix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { onMenu() }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: onNewGame) {
                        Text("Nuevo juego")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "F43F5E"))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button(action: onRanking) {
                        Text("Ver Ranking")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
    }

    private func roundRow(index: Int, round: ColorRound) -> some View {
        let score = round.score ?? 0
        return HStack(spacing: 12) {
            Text("R\(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(Color(hex: "94A3B8"))
                .frame(width: 28)

            // Color swatches
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(round.targetColor)
                    .frame(width: 28, height: 28)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "64748B"))
                RoundedRectangle(cornerRadius: 6)
                    .fill(round.guessColor)
                    .frame(width: 28, height: 28)
            }

            // Delta per channel
            VStack(alignment: .leading, spacing: 2) {
                channelDelta(label: "R", target: round.targetR, guess: round.guessR, accent: Color(hex: "EF4444"))
                channelDelta(label: "G", target: round.targetG, guess: round.guessG, accent: Color(hex: "22C55E"))
                channelDelta(label: "B", target: round.targetB, guess: round.guessB, accent: Color(hex: "3B82F6"))
            }

            Spacer()

            // Score badge
            Text("\(score)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(scoreColor(score, max: 100))
                .frame(width: 40, alignment: .trailing)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func channelDelta(label: String, target: Double, guess: Double, accent: Color) -> some View {
        let delta = abs(Int(target) - Int(guess))
        return HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 10)
            Text("Δ\(delta)")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(delta < 15 ? Color(hex: "22C55E") : delta < 40 ? Color(hex: "EAB308") : Color(hex: "EF4444"))
        }
    }

    private func scoreColor(_ score: Int, max: Int) -> Color {
        let pct = Double(score) / Double(max)
        if pct >= 0.9 { return Color(hex: "22C55E") }
        if pct >= 0.7 { return Color(hex: "EAB308") }
        return Color(hex: "EF4444")
    }
}
