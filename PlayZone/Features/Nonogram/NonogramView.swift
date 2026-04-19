import SwiftUI

struct NonogramView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: NonogramGame
    @State private var showResult  = false
    @State private var isNewRecord = false
    @State private var showInfo            = false
    @State private var navigatedToRanking  = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path      = path
        self._game      = State(initialValue: NonogramGame(difficulty: difficulty))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 12) {
                hud
                GeometryReader { geo in
                    puzzle(in: geo.size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .overlay {
            if navigatedToRanking {
                PostRankingOverlay(
                    onNewGame: { navigatedToRanking = false; game.reset() },
                    onMenu:    { navigatedToRanking = false; path.removeLast(path.count) }
                )
            }
        }
        .navigationTitle("Nonograma · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .nonogram) }
        .onChange(of: game.isComplete) { _, complete in
            if complete {
                Task {
                    await submitScore()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showResult = true }
                }
            }
        }
        .alert("¡Nonograma Completado! 🎉", isPresented: $showResult) {
            Button("Nuevo juego") { game.reset() }
            Button("Ver Ranking") { navigatedToRanking = true; path.append(Route.ranking(.nonogram)) }
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
            Button { game.reset() } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Puzzle layout

    // Compact per-clue-number slot size, tuned per difficulty:
    //   easy  5×5  → 18 pt slot, 14 pt font
    //   medium 10×10 → 14 pt slot, 11 pt font
    //   hard  15×15 → 11 pt slot,  9 pt font
    // rowClueW = maxGroupsInAnyRow  × slot + (n-1)×1 spacing + 4 gap to grid
    // colClueH = maxGroupsInAnyCol  × slot + (n-1)×1 spacing + 4 gap to grid
    // This is ~40 % narrower than the previous formula, giving ~20–25 % more cell width.

    @ViewBuilder
    private func puzzle(in size: CGSize) -> some View {
        let n = game.size
        let font:  CGFloat = n <= 5 ? 14 : n <= 10 ? 11 : 9
        let slot:  CGFloat = n <= 5 ? 18 : n <= 10 ? 14 : 11

        let maxRowLen = game.rowClues.map(\.count).max() ?? 1
        let maxColLen = game.colClues.map(\.count).max() ?? 1

        // Total space for clues = numCount × slot + (numCount-1) × 1pt gap + 4pt gap to grid
        let rowClueW = CGFloat(maxRowLen) * slot + CGFloat(max(0, maxRowLen - 1)) + 4
        let colClueH = CGFloat(maxColLen) * slot + CGFloat(max(0, maxColLen - 1)) + 4

        // Separator widths between cells (1 pt normal, 2 pt at every 5th boundary)
        let gaps   = max(0, n - 1)
        let thick  = n > 5 ? gaps / 5 : 0
        let sepPts = CGFloat(gaps - thick) + CGFloat(thick) * 2

        let cs = max(16, min(
            (size.width  - rowClueW - sepPts) / CGFloat(n),
            (size.height - colClueH - sepPts) / CGFloat(n)
        ))

        VStack(alignment: .leading, spacing: 0) {
            // Column clue header
            HStack(spacing: 0) {
                Color.clear.frame(width: rowClueW, height: colClueH)
                ForEach(0..<n, id: \.self) { col in
                    if col > 0 {
                        Rectangle()
                            .fill(n > 5 && col % 5 == 0 ? Color(hex: "64748B") : Color(hex: "334155"))
                            .frame(width: n > 5 && col % 5 == 0 ? 2 : 1, height: colClueH)
                    }
                    colClueCell(col: col, maxLen: maxColLen, cellW: cs, clueH: colClueH, font: font, slot: slot)
                }
            }

            // Game rows
            ForEach(0..<n, id: \.self) { row in
                if row > 0 {
                    Rectangle()
                        .fill(n > 5 && row % 5 == 0 ? Color(hex: "64748B") : Color(hex: "334155"))
                        .frame(height: n > 5 && row % 5 == 0 ? 2 : 1)
                }
                HStack(spacing: 0) {
                    rowClueCell(row: row, maxLen: maxRowLen, cellH: cs, clueW: rowClueW, font: font, slot: slot)
                    ForEach(0..<n, id: \.self) { col in
                        if col > 0 {
                            Rectangle()
                                .fill(n > 5 && col % 5 == 0 ? Color(hex: "64748B") : Color(hex: "334155"))
                                .frame(width: n > 5 && col % 5 == 0 ? 2 : 1, height: cs)
                        }
                        gameCell(row: row, col: col, size: cs)
                    }
                }
            }
        }
    }

    // Numbers bottom-aligned, one per slot row, centred in the cell column width.
    private func colClueCell(col: Int, maxLen: Int,
                             cellW: CGFloat, clueH: CGFloat,
                             font: CGFloat, slot: CGFloat) -> some View {
        let nums = game.colClues[col]
        return VStack(spacing: 1) {
            Spacer(minLength: 0)
            ForEach(Array(nums.enumerated()), id: \.offset) { _, n in
                Text(n == 0 ? "·" : "\(n)")
                    .font(.system(size: font, weight: .bold, design: .monospaced))
                    .foregroundStyle(n == 0 ? Color(hex: "475569") : .white)
                    .frame(width: cellW, height: slot)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            // 4 pt breathing room above the grid
            Color.clear.frame(height: 4)
        }
        .frame(width: cellW, height: clueH)
    }

    // Numbers right-aligned, one per slot column, row centred in the cell height.
    private func rowClueCell(row: Int, maxLen: Int,
                             cellH: CGFloat, clueW: CGFloat,
                             font: CGFloat, slot: CGFloat) -> some View {
        let nums = game.rowClues[row]
        return HStack(spacing: 1) {
            Spacer(minLength: 0)
            ForEach(Array(nums.enumerated()), id: \.offset) { _, n in
                Text(n == 0 ? "·" : "\(n)")
                    .font(.system(size: font, weight: .bold, design: .monospaced))
                    .foregroundStyle(n == 0 ? Color(hex: "475569") : .white)
                    .frame(width: slot, height: cellH)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            // 4 pt breathing room to the right of the numbers, before the grid
            Color.clear.frame(width: 4)
        }
        .frame(width: clueW, height: cellH)
    }

    private func gameCell(row: Int, col: Int, size: CGFloat) -> some View {
        let state = game.marks[row][col]
        return ZStack {
            Rectangle()
                .fill(state == .filled ? Color(hex: "6366F1") : Color(hex: "1E293B"))
            if state == .crossed {
                Image(systemName: "xmark")
                    .font(.system(size: max(8, size * 0.38), weight: .bold))
                    .foregroundStyle(Color(hex: "64748B"))
            }
        }
        .frame(width: size, height: size)
        .onTapGesture { game.tap(row, col) }
    }

    // MARK: - Helpers

    private func formattedTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func submitScore() async {
        let current      = try? await rankingService.fetch(game: .nonogram, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .nonogram,
                                 difficulty: difficulty, value: game.finalMilliseconds)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.finalMilliseconds < previousBest!
    }
}
