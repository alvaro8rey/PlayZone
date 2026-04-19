import SwiftUI

// MARK: - Pointy-top hexagon shape

private struct HexShape: Shape {
    func path(in rect: CGRect) -> Path {
        let R  = min(rect.width / CGFloat(sqrt(3.0)), rect.height / 2)
        let cx = rect.midX, cy = rect.midY
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2   // start at top vertex
            let pt = CGPoint(x: cx + R * cos(angle), y: cy + R * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - View

struct SpellingBeeView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: SpellingBeeGame
    @State private var showFoundWords = false
    @State private var showInfo = false
    @State private var feedbackText   = ""
    @State private var feedbackColor  = Color.green
    @State private var showFeedback   = false
    @State private var isNewRecord    = false
    @State private var hoveredHexIndex: Int? = nil
    @AppStorage("playerName") private var playerName = ""
    @Environment(\.rankingService)   private var rankingService

    private var recordKey: String { "spellingBee_record_\(difficulty.rawValue)" }
    @AppStorage private var record: Int

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty  = difficulty
        self._path       = path
        self._game       = State(initialValue: SpellingBeeGame(difficulty: difficulty))
        self._record     = AppStorage(wrappedValue: 0, "spellingBee_record_\(difficulty.rawValue)")
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 12) {
                hud
                progressSection
                inputDisplay
                Spacer(minLength: 0)
                hexGrid
                Spacer(minLength: 0)
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Feedback banner
            if showFeedback {
                VStack {
                    Spacer()
                    Text(feedbackText)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(feedbackColor)
                        .clipShape(Capsule())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("Spelling Bee · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .spellingBee) }
        .sheet(isPresented: $showFoundWords) { foundWordsSheet }
    }

    // MARK: - HUD

    private var hud: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Puntuación: \(game.score)")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text("Rango: \(game.rank)")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "94A3B8"))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Récord: \(record)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(hex: "94A3B8"))
                Button {
                    saveScoreIfBetter()
                    game.newGame()
                } label: {
                    Text("Nuevo")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(hex: "3B82F6"))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "334155"))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "EAB308"))
                        .frame(width: geo.size.width * game.progress, height: 6)
                    // Tick marks at rank thresholds
                    ForEach([0.05, 0.20, 0.40, 0.60, 0.80], id: \.self) { pct in
                        Rectangle()
                            .fill(Color(hex: "0F172A"))
                            .frame(width: 2, height: 10)
                            .offset(x: geo.size.width * pct - 1, y: -2)
                    }
                }
            }
            .frame(height: 10)

            Button {
                showFoundWords = true
            } label: {
                Text("Palabras encontradas: \(game.score) de \(game.totalWords)")
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: "3B82F6"))
            }
        }
    }

    // MARK: - Input display

    private var inputDisplay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "1E293B"))

            if game.currentInput.isEmpty {
                Text("Escribe una palabra...")
                    .font(.title3.bold())
                    .foregroundStyle(Color(hex: "475569"))
            } else {
                Text(game.currentInput.uppercased())
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
            }
        }
        .frame(height: 52)
    }

    // MARK: - Hex grid

    private var hexGrid: some View {
        GeometryReader { geo in
            let maxR = min(geo.size.width / (3 * sqrt(3.0)), geo.size.height / 5)
            let R    = min(maxR, 56.0)
            let dx   = R * sqrt(3.0)
            let dy   = R * 1.5
            let cx   = geo.size.width  / 2
            let cy   = geo.size.height / 2

            let positions: [(CGFloat, CGFloat)] = [
                (cx,           cy      ),   // 0 center
                (cx - dx,      cy      ),   // 1 left
                (cx + dx,      cy      ),   // 2 right
                (cx - dx / 2,  cy - dy ),   // 3 upper-left
                (cx + dx / 2,  cy - dy ),   // 4 upper-right
                (cx - dx / 2,  cy + dy ),   // 5 lower-left
                (cx + dx / 2,  cy + dy ),   // 6 lower-right
            ]
            let letters = [game.centerLetter] + game.outerLetters

            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    hexCell(letter: letters[i], isCenter: i == 0,
                            isHovered: hoveredHexIndex == i, R: R)
                        .position(x: positions[i].0, y: positions[i].1)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        // Only highlight — letter is NOT added until finger lifts
                        let pt = val.location
                        var hit: Int? = nil
                        for (i, pos) in positions.enumerated() {
                            if hypot(pt.x - pos.0, pt.y - pos.1) < R * 0.92 {
                                hit = i; break
                            }
                        }
                        hoveredHexIndex = hit
                    }
                    .onEnded { val in
                        defer { hoveredHexIndex = nil }
                        guard game.currentInput.count < 5 else { return }
                        let pt = val.location
                        for (i, pos) in positions.enumerated() {
                            if hypot(pt.x - pos.0, pt.y - pos.1) < R * 0.92 {
                                game.addLetter(letters[i])
                                if game.currentInput.count == 5 {
                                    handleSubmit()
                                }
                                return
                            }
                        }
                    }
            )
        }
    }

    private func hexCell(letter: Character, isCenter: Bool, isHovered: Bool, R: CGFloat) -> some View {
        ZStack {
            HexShape()
                .fill(isHovered ? Color.white
                      : isCenter ? Color(hex: "EAB308")
                      : Color(hex: "B45309"))
                .overlay(HexShape().stroke(Color.black.opacity(0.2), lineWidth: 1))
            Text(String(letter).uppercased())
                .font(.system(size: R * 0.55, weight: .bold))
                .foregroundStyle(isHovered ? Color.black : .white)
        }
        .frame(width: R * sqrt(3.0), height: R * 2.0)
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isHovered)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            actionBtn("Borrar", color: Color(hex: "EF4444")) {
                game.deleteLast()
            }
            actionBtn("Mezclar", color: Color(hex: "3B82F6")) {
                game.shuffle()
            }
            actionBtn("Enviar", color: Color(hex: "22C55E")) {
                handleSubmit()
            }
        }
    }

    private func actionBtn(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .clipShape(Capsule())
        }
    }

    // MARK: - Found words sheet

    private var foundWordsSheet: some View {
        NavigationStack {
            List(game.foundWords.sorted(), id: \.self) { word in
                Text(word.uppercased())
                    .font(.body.bold())
            }
            .navigationTitle("Palabras encontradas (\(game.score))")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    private func handleSubmit() {
        let result = game.submit()
        let (text, color): (String, Color) = switch result {
        case .found:        ("¡Encontrada! 🎉",                     Color(hex: "22C55E"))
        case .alreadyFound: ("Ya la encontraste",                    Color(hex: "EAB308"))
        case .notValid:     ("No está en la lista",                  Color(hex: "EF4444"))
        case .noCenter:     ("Debe contener la letra central",       Color(hex: "F97316"))
        case .tooShort:     ("Mínimo 5 letras",                      Color(hex: "F97316"))
        }
        showBanner(text, color: color)
        if result == .found { saveScoreIfBetter() }
    }

    private func showBanner(_ text: String, color: Color) {
        feedbackText  = text
        feedbackColor = color
        withAnimation(.easeInOut(duration: 0.2)) { showFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.3)) { showFeedback = false }
        }
    }

    private func saveScoreIfBetter() {
        guard game.score > 0 else { return }
        if game.score > record { record = game.score }
        Task {
            let entry = RankingEntry(playerName: playerName, game: .spellingBee,
                                     difficulty: difficulty, value: game.score)
            try? await rankingService.save(entry)
        }
    }
}
