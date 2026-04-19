import SwiftUI

struct NonogramView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: NonogramGame
    @State private var showResult  = false
    @State private var isNewRecord = false
    @State private var showInfo           = false
    @State private var navigatedToRanking = false

    // Zoom & pan
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize  = .zero
    @State private var geoSize:   CGSize  = .zero

    private let panStep:  CGFloat = 90
    private let zoomStep: CGFloat = 0.75
    private let maxZoom:  CGFloat = 3.0

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

            VStack(spacing: 8) {
                hud

                // Puzzle + pan arrow overlay
                GeometryReader { geo in
                    puzzle(in: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                        .scaleEffect(zoomScale, anchor: .center)
                        .offset(panOffset)
                        .clipped()
                        .onAppear            { geoSize = geo.size }
                        .onChange(of: geo.size) { _, s in geoSize = s }
                }
                .overlay {
                    if zoomScale > 1.0 {
                        panArrowsOverlay
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: zoomScale > 1.0)
                    }
                }

                zoomBar
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
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

    // MARK: - Zoom bar (two fixed buttons)

    private var zoomBar: some View {
        HStack(spacing: 20) {
            Spacer()
            Button { doZoomOut() } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(zoomScale > 1.0 ? .white : Color(hex: "475569"))
                    .frame(width: 52, height: 44)
                    .background(Color(hex: "1E293B"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(zoomScale <= 1.0)

            Button { doZoomIn() } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(zoomScale < maxZoom ? .white : Color(hex: "475569"))
                    .frame(width: 52, height: 44)
                    .background(Color(hex: "1E293B"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(zoomScale >= maxZoom)
            Spacer()
        }
        .frame(height: 56)
    }

    // MARK: - Pan arrows overlaid on the puzzle

    private var panArrowsOverlay: some View {
        ZStack {
            // Top & Bottom
            VStack {
                panArrowButton("chevron.compact.up") { doPan(dy: panStep) }
                Spacer()
                panArrowButton("chevron.compact.down") { doPan(dy: -panStep) }
            }
            .frame(maxWidth: .infinity)

            // Left & Right
            HStack {
                panArrowButton("chevron.compact.left") { doPan(dx: panStep) }
                Spacer()
                panArrowButton("chevron.compact.right") { doPan(dx: -panStep) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func panArrowButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.40))
                .clipShape(Circle())
        }
        .padding(10)
    }

    // MARK: - Zoom / pan helpers

    private func doZoomIn() {
        withAnimation(.easeInOut(duration: 0.22)) {
            zoomScale = min(maxZoom, zoomScale + zoomStep)
        }
    }

    private func doZoomOut() {
        withAnimation(.easeInOut(duration: 0.22)) {
            zoomScale = max(1.0, zoomScale - zoomStep)
            if zoomScale <= 1.0 { panOffset = .zero }
        }
        reclampOffset()
    }

    private func doPan(dx: CGFloat = 0, dy: CGFloat = 0) {
        let maxH = (zoomScale - 1.0) / 2 * max(geoSize.width,  1)
        let maxV = (zoomScale - 1.0) / 2 * max(geoSize.height, 1)
        withAnimation(.easeInOut(duration: 0.15)) {
            panOffset = CGSize(
                width:  max(-maxH, min(maxH, panOffset.width  + dx)),
                height: max(-maxV, min(maxV, panOffset.height + dy))
            )
        }
    }

    private func reclampOffset() {
        let maxH = max(0, (zoomScale - 1.0) / 2 * geoSize.width)
        let maxV = max(0, (zoomScale - 1.0) / 2 * geoSize.height)
        withAnimation(.easeInOut(duration: 0.15)) {
            panOffset = CGSize(
                width:  max(-maxH, min(maxH, panOffset.width)),
                height: max(-maxV, min(maxV, panOffset.height))
            )
        }
    }

    // MARK: - Puzzle layout

    @ViewBuilder
    private func puzzle(in size: CGSize) -> some View {
        let n = game.size
        let font:  CGFloat = n <= 5 ? 14 : n <= 10 ? 11 : 9
        let slot:  CGFloat = n <= 5 ? 18 : n <= 10 ? 14 : 11

        let maxRowLen = game.rowClues.map(\.count).max() ?? 1
        let maxColLen = game.colClues.map(\.count).max() ?? 1

        let rowClueW = CGFloat(maxRowLen) * slot + CGFloat(max(0, maxRowLen - 1)) + 4
        let colClueH = CGFloat(maxColLen) * slot + CGFloat(max(0, maxColLen - 1)) + 4

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
                // Top-left corner matches clue background
                Color(hex: "1A3254").frame(width: rowClueW, height: colClueH)
                ForEach(0..<n, id: \.self) { col in
                    if col > 0 { separatorV(col: col, n: n, h: colClueH) }
                    colClueCell(col: col, cellW: cs, clueH: colClueH, font: font, slot: slot)
                }
            }

            // Game rows
            ForEach(0..<n, id: \.self) { row in
                if row > 0 { separatorH(row: row, n: n) }
                HStack(spacing: 0) {
                    rowClueCell(row: row, cellH: cs, clueW: rowClueW, font: font, slot: slot)
                    ForEach(0..<n, id: \.self) { col in
                        if col > 0 { separatorV(col: col, n: n, h: cs) }
                        gameCell(row: row, col: col, size: cs)
                    }
                }
            }
        }
    }

    // MARK: - Grid separators

    @ViewBuilder
    private func separatorH(row: Int, n: Int) -> some View {
        let thick = n > 5 && row % 5 == 0
        Rectangle()
            .fill(thick ? Color(hex: "475569") : Color(hex: "2D3E54"))
            .frame(height: thick ? 2 : 1)
    }

    @ViewBuilder
    private func separatorV(col: Int, n: Int, h: CGFloat) -> some View {
        let thick = n > 5 && col % 5 == 0
        Rectangle()
            .fill(thick ? Color(hex: "475569") : Color(hex: "2D3E54"))
            .frame(width: thick ? 2 : 1, height: h)
    }

    // MARK: - Clue cells with alternating bands and completion color

    // Clue band: alternates every 2 rows/cols
    private func clueBg(index: Int, isComplete: Bool) -> Color {
        if isComplete { return Color(hex: "0B3320") }
        return (index / 2) % 2 == 0 ? Color(hex: "1A3254") : Color(hex: "213C64")
    }

    private func colClueCell(col: Int, cellW: CGFloat, clueH: CGFloat,
                             font: CGFloat, slot: CGFloat) -> some View {
        let nums     = game.colClues[col]
        let complete = game.isColComplete(col)
        let txtColor: Color = complete ? Color(hex: "4ADE80") : Color(hex: "CBD5E1")
        return VStack(spacing: 1) {
            Spacer(minLength: 0)
            ForEach(Array(nums.enumerated()), id: \.offset) { _, n in
                Text(n == 0 ? "·" : "\(n)")
                    .font(.system(size: font, weight: .bold, design: .monospaced))
                    .foregroundStyle(n == 0 ? Color(hex: "475569") : txtColor)
                    .frame(width: cellW, height: slot)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            Color.clear.frame(height: 4)
        }
        .frame(width: cellW, height: clueH)
        .background(clueBg(index: col, isComplete: complete))
    }

    private func rowClueCell(row: Int, cellH: CGFloat, clueW: CGFloat,
                             font: CGFloat, slot: CGFloat) -> some View {
        let nums     = game.rowClues[row]
        let complete = game.isRowComplete(row)
        let txtColor: Color = complete ? Color(hex: "4ADE80") : Color(hex: "CBD5E1")
        return HStack(spacing: 1) {
            Spacer(minLength: 0)
            ForEach(Array(nums.enumerated()), id: \.offset) { _, n in
                Text(n == 0 ? "·" : "\(n)")
                    .font(.system(size: font, weight: .bold, design: .monospaced))
                    .foregroundStyle(n == 0 ? Color(hex: "475569") : txtColor)
                    .frame(width: slot, height: cellH)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            Color.clear.frame(width: 4)
        }
        .frame(width: clueW, height: cellH)
        .background(clueBg(index: row, isComplete: complete))
    }

    // MARK: - Game cell

    private func gameCell(row: Int, col: Int, size: CGFloat) -> some View {
        let state = game.marks[row][col]
        return ZStack {
            Rectangle()
                .fill(state == .filled ? Color(hex: "6366F1") : Color(hex: "0D1B2C"))
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
