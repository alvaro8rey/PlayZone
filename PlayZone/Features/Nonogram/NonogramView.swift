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

    private let panStep:  CGFloat = 80
    private let zoomStep: CGFloat = 0.5
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
                GeometryReader { geo in
                    puzzle(in: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                        .scaleEffect(zoomScale, anchor: .center)
                        .offset(panOffset)
                        .clipped()
                        .onAppear { geoSize = geo.size }
                        .onChange(of: geo.size) { _, s in geoSize = s }
                }
                zoomBar
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
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
        .onChange(of: game.marks) { _, _ in
            // Reset zoom when puzzle is reset
            if !game.isComplete && game.elapsedSeconds == 0 {
                withAnimation { zoomScale = 1.0; panOffset = .zero }
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

    // MARK: - Zoom bar

    private var zoomBar: some View {
        HStack(alignment: .center, spacing: 16) {
            // Zoom controls
            HStack(spacing: 0) {
                Button { doZoomOut() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(zoomScale > 1.0 ? .white : Color(hex: "334155"))
                }
                .disabled(zoomScale <= 1.0)

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(Color(hex: "94A3B8"))
                    .frame(width: 48)

                Button { doZoomIn() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(zoomScale < maxZoom ? .white : Color(hex: "334155"))
                }
                .disabled(zoomScale >= maxZoom)
            }
            .background(Color(hex: "1E293B"))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            // Directional pad — visible only when zoomed in
            if zoomScale > 1.0 {
                VStack(spacing: 3) {
                    arrowBtn("chevron.up")    { doPan(dy: -panStep) }
                    HStack(spacing: 3) {
                        arrowBtn("chevron.left")  { doPan(dx: -panStep) }
                        Color.clear.frame(width: 30, height: 30)
                        arrowBtn("chevron.right") { doPan(dx:  panStep) }
                    }
                    arrowBtn("chevron.down")  { doPan(dy:  panStep) }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 88)
        .animation(.easeInOut(duration: 0.2), value: zoomScale > 1.0)
    }

    private func arrowBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color(hex: "1E293B"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Zoom / pan helpers

    private func doZoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = min(maxZoom, zoomScale + zoomStep)
        }
    }

    private func doZoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
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
                Color.clear.frame(width: rowClueW, height: colClueH)
                ForEach(0..<n, id: \.self) { col in
                    if col > 0 {
                        separatorV(col: col, n: n, height: colClueH)
                    }
                    colClueCell(col: col, maxLen: maxColLen, cellW: cs,
                                clueH: colClueH, font: font, slot: slot)
                }
            }

            // Game rows
            ForEach(0..<n, id: \.self) { row in
                if row > 0 {
                    separatorH(row: row, n: n)
                }
                HStack(spacing: 0) {
                    rowClueCell(row: row, maxLen: maxRowLen, cellH: cs,
                                clueW: rowClueW, font: font, slot: slot)
                    ForEach(0..<n, id: \.self) { col in
                        if col > 0 {
                            separatorV(col: col, n: n, height: cs)
                        }
                        gameCell(row: row, col: col, size: cs)
                    }
                }
            }
        }
    }

    // MARK: - Separators

    @ViewBuilder
    private func separatorH(row: Int, n: Int) -> some View {
        let isThick = n > 5 && row % 5 == 0
        Rectangle()
            .fill(isThick ? Color(hex: "4B5563") : Color(hex: "2D3E52"))
            .frame(height: isThick ? 2 : 1)
    }

    @ViewBuilder
    private func separatorV(col: Int, n: Int, height: CGFloat) -> some View {
        let isThick = n > 5 && col % 5 == 0
        Rectangle()
            .fill(isThick ? Color(hex: "4B5563") : Color(hex: "2D3E52"))
            .frame(width: isThick ? 2 : 1, height: height)
    }

    // MARK: - Clue cells

    // Alternating band colors for every 2 rows/cols
    private func bandBg(index: Int, isComplete: Bool) -> Color {
        if isComplete { return Color(hex: "082A14") }
        return (index / 2) % 2 == 0 ? Color(hex: "1E293B") : Color(hex: "0E1C2C")
    }

    private func clueTextColor(isComplete: Bool, isZero: Bool) -> Color {
        if isZero    { return Color(hex: "475569") }
        if isComplete { return Color(hex: "4ADE80") }
        return .white
    }

    private func colClueCell(col: Int, maxLen: Int,
                             cellW: CGFloat, clueH: CGFloat,
                             font: CGFloat, slot: CGFloat) -> some View {
        let nums       = game.colClues[col]
        let complete   = game.isColComplete(col)
        return VStack(spacing: 1) {
            Spacer(minLength: 0)
            ForEach(Array(nums.enumerated()), id: \.offset) { _, n in
                Text(n == 0 ? "·" : "\(n)")
                    .font(.system(size: font, weight: .bold, design: .monospaced))
                    .foregroundStyle(clueTextColor(isComplete: complete, isZero: n == 0))
                    .frame(width: cellW, height: slot)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            Color.clear.frame(height: 4)
        }
        .frame(width: cellW, height: clueH)
        .background(bandBg(index: col, isComplete: complete))
    }

    private func rowClueCell(row: Int, maxLen: Int,
                             cellH: CGFloat, clueW: CGFloat,
                             font: CGFloat, slot: CGFloat) -> some View {
        let nums     = game.rowClues[row]
        let complete = game.isRowComplete(row)
        return HStack(spacing: 1) {
            Spacer(minLength: 0)
            ForEach(Array(nums.enumerated()), id: \.offset) { _, n in
                Text(n == 0 ? "·" : "\(n)")
                    .font(.system(size: font, weight: .bold, design: .monospaced))
                    .foregroundStyle(clueTextColor(isComplete: complete, isZero: n == 0))
                    .frame(width: slot, height: cellH)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            Color.clear.frame(width: 4)
        }
        .frame(width: clueW, height: cellH)
        .background(bandBg(index: row, isComplete: complete))
    }

    // MARK: - Game cell

    private func gameCell(row: Int, col: Int, size: CGFloat) -> some View {
        let state      = game.marks[row][col]
        let isEvenBand = (row / 2) % 2 == 0
        let emptyColor = isEvenBand ? Color(hex: "1E293B") : Color(hex: "0E1C2C")
        return ZStack {
            Rectangle()
                .fill(state == .filled ? Color(hex: "6366F1") : emptyColor)
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
