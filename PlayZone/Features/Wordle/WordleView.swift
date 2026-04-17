import SwiftUI

struct WordleView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: WordleGame
    @State private var showResult = false
    @State private var isNewRecord = false
    @State private var shakeRow: Int? = nil
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: WordleGame(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            if game.isLoading {
                loadingView
            } else {
                VStack(spacing: 16) {
                    tileGrid
                        .padding(.horizontal, 16)
                    Spacer()
                    keyboard
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("Wordle · \(difficulty.rawValue) (\(game.wordLength) letras)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: game.state) { _, st in
            guard st != .playing else { return }
            Task {
                if st == .won { await submitScore() }
                try? await Task.sleep(nanoseconds: 800_000_000)
                showResult = true
            }
        }
        .alert(game.state == .won ? "¡Lo conseguiste! 🎉" : "Game Over", isPresented: $showResult) {
            Button("Reintentar") { game.reset() }
            Button("Menú") { path.removeLast(path.count) }
        } message: {
            if game.state == .won {
                let base = "La palabra era: \(game.targetWord.uppercased())"
                if isNewRecord {
                    Text("🏆 ¡Nuevo récord!  \(game.score) pts\n\(base)")
                } else {
                    Text("\(game.score) pts\n\(base)")
                }
            } else {
                Text("La palabra era: \(game.targetWord.uppercased())")
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
            Text("Cargando palabra...")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "94A3B8"))
        }
    }

    // MARK: - Tile Grid

    private var tileGrid: some View {
        VStack(spacing: 6) {
            ForEach(0..<game.maxAttempts, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<game.wordLength, id: \.self) { col in
                        TileView(
                            letter: letter(row: row, col: col),
                            state: tileState(row: row, col: col),
                            revealed: row < game.currentRow,
                            revealDelay: Double(col) * 0.1
                        )
                    }
                }
                .modifier(ShakeEffect(trigger: shakeRow == row))
            }
        }
    }

    private func letter(row: Int, col: Int) -> Character? {
        if row < game.guesses.count {
            return game.guesses[row][col]
        }
        if row == game.currentRow {
            let chars = Array(game.currentGuess)
            return col < chars.count ? chars[col] : nil
        }
        return nil
    }

    private func tileState(row: Int, col: Int) -> LetterState {
        guard row < game.letterStates.count else { return .unknown }
        return game.letterStates[row][col]
    }

    // MARK: - Keyboard

    private let rows: [[Character]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L","Ñ"],
        ["↵","Z","X","C","V","B","N","M","⌫"]
    ]

    private var keyboard: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 5) {
                    ForEach(rows[r], id: \.self) { key in
                        KeyButton(key: key, state: keyState(key)) {
                            handleKey(key)
                        }
                    }
                }
            }
        }
    }

    private func keyState(_ key: Character) -> LetterState {
        keyboardState(for: key)
    }

    private func keyboardState(for key: Character) -> LetterState {
        let lower = Character(String(key).lowercased())
        return game.keyboardState[lower] ?? .unknown
    }

    private func handleKey(_ key: Character) {
        guard game.state == .playing else { return }
        switch key {
        case "⌫": game.deleteLetter()
        case "↵":
            let submitted = game.submitGuess()
            if !submitted {
                withAnimation { shakeRow = game.currentRow }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shakeRow = nil }
            }
        default:
            game.addLetter(Character(String(key).lowercased()))
        }
    }

    // MARK: - Submit

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .wordle, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .wordle,
                                 difficulty: difficulty, value: game.score)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.score > previousBest!
    }
}

// MARK: - Tile View

struct TileView: View {
    let letter: Character?
    let state: LetterState
    let revealed: Bool
    let revealDelay: Double

    @State private var flipped = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(bgColor)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 2))

            if let ch = letter {
                Text(String(ch).uppercased())
                    .font(.title2.bold())
                    .foregroundStyle(revealed ? .white : Color(hex: "E2E8F0"))
                    .scaleEffect(flipped ? 1 : 0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .rotation3DEffect(.degrees(flipped ? 0 : 0), axis: (1, 0, 0))
        .onChange(of: revealed) { _, isRevealed in
            if isRevealed {
                withAnimation(.easeInOut(duration: 0.3).delay(revealDelay)) {
                    flipped = true
                }
            }
        }
        .onChange(of: letter) { _, _ in
            if !revealed { flipped = false }
        }
    }

    private var bgColor: Color {
        if !revealed { return letter == nil ? Color(hex: "1E293B") : Color(hex: "334155") }
        switch state {
        case .correct:  return Color(hex: "16A34A")
        case .present:  return Color(hex: "D97706")
        case .absent:   return Color(hex: "475569")
        case .unknown:  return Color(hex: "1E293B")
        }
    }

    private var borderColor: Color {
        if !revealed { return letter == nil ? Color(hex: "334155") : Color(hex: "94A3B8") }
        return .clear
    }
}

// MARK: - Key Button

struct KeyButton: View {
    let key: Character
    let state: LetterState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(key))
                .font(.system(size: key == "↵" || key == "⌫" ? 13 : 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(width: key == "↵" || key == "⌫" ? 46 : nil)
    }

    private var bgColor: Color {
        switch state {
        case .correct:  return Color(hex: "16A34A")
        case .present:  return Color(hex: "D97706")
        case .absent:   return Color(hex: "374151")
        case .unknown:  return Color(hex: "4B5563")
        }
    }
}

// MARK: - Shake Effect

struct ShakeEffect: ViewModifier {
    let trigger: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: trigger ? 8 : 0)
            .animation(
                trigger
                ? .interpolatingSpring(stiffness: 600, damping: 10).repeatCount(3, autoreverses: true)
                : .default,
                value: trigger
            )
    }
}
