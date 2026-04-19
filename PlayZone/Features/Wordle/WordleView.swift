import SwiftUI
import UIKit

struct WordleView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: WordleGame
    @State private var showResult = false
    @State private var isNewRecord = false
    @State private var shakeRow: Int? = nil
    @State private var showInfo            = false
    @State private var navigatedToRanking  = false
    @State private var keyboardFocused = false
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
                VStack(spacing: 0) {
                    tileGrid
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                    Spacer()
                    NativeKeyboardInput(focused: $keyboardFocused, onKey: handleKey)
                        .frame(width: 1, height: 1)
                        .opacity(0.001)
                }
            }
        }
        .overlay {
            if navigatedToRanking {
                PostRankingOverlay(
                    onNewGame: { navigatedToRanking = false; game.reset(); keyboardFocused = true },
                    onMenu:    { navigatedToRanking = false; path.removeLast(path.count) }
                )
            }
        }
        .navigationTitle("Wordle · \(difficulty.rawValue) (\(game.wordLength) letras)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .wordle) }
        .onAppear { keyboardFocused = true }
        .onChange(of: game.state) { _, st in
            guard st != .playing else { return }
            keyboardFocused = false
            Task {
                if st == .won { await submitScore() }
                try? await Task.sleep(nanoseconds: 800_000_000)
                showResult = true
            }
        }
        .alert(game.state == .won ? "¡Lo conseguiste! 🎉" : "Game Over", isPresented: $showResult) {
            Button("Reintentar") { game.reset(); keyboardFocused = true }
            Button("Ver Ranking") { navigatedToRanking = true; path.append(Route.ranking(.wordle)) }
            Button("Menú", role: .cancel) { path.removeLast(path.count) }
        } message: {
            if game.state == .won {
                let streakText = game.currentStreak == 1
                    ? "1 victoria seguida"
                    : "\(game.currentStreak) victorias seguidas"
                Text(isNewRecord
                     ? "🏆 ¡Mejor racha!  \(streakText)\nLa palabra era: \(game.targetWord.uppercased())"
                     : "Racha: \(streakText)\nLa palabra era: \(game.targetWord.uppercased())")
            } else {
                Text("Racha rota 💔\nLa palabra era: \(game.targetWord.uppercased())")
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white).scaleEffect(1.4)
            Text("Cargando palabra...")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "94A3B8"))
        }
    }

    // MARK: - Tile Grid

    private var tileGrid: some View {
        VStack(spacing: 8) {
            ForEach(0..<game.maxAttempts, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<game.wordLength, id: \.self) { col in
                        let isCurrentRow = row == game.currentRow
                        let isSelected = isCurrentRow && col == game.selectedCol
                        TileView(
                            letter: letter(row: row, col: col),
                            state: tileState(row: row, col: col),
                            revealed: row < game.currentRow,
                            revealDelay: Double(col) * 0.1,
                            isSelected: isSelected
                        )
                        .onTapGesture {
                            if isCurrentRow && game.state == .playing {
                                game.selectCol(col)
                                keyboardFocused = true
                            }
                        }
                    }
                }
                .modifier(ShakeEffect(trigger: shakeRow == row))
            }
        }
    }

    private func letter(row: Int, col: Int) -> Character? {
        if row < game.guesses.count { return game.guesses[row][col] }
        if row == game.currentRow { return game.currentTiles[col] }
        return nil
    }

    private func tileState(row: Int, col: Int) -> LetterState {
        guard row < game.letterStates.count else { return .unknown }
        return game.letterStates[row][col]
    }

    // MARK: - Key handling

    private func handleKey(_ key: Character?) {
        guard game.state == .playing else { return }
        if let ch = key {
            game.addLetter(Character(String(ch).lowercased()))
            if game.isCurrentGuessFull {
                _ = game.submitGuess()
            }
        } else {
            game.deleteLetter()
        }
    }

    // MARK: - Submit score

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .wordle, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .wordle,
                                 difficulty: difficulty, value: game.score)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.score > previousBest!
    }
}

// MARK: - Native keyboard bridge

private class BackspaceTextField: UITextField {
    var onBackspace: (() -> Void)?
    override func deleteBackward() {
        onBackspace?()
        super.deleteBackward()
    }
}

struct NativeKeyboardInput: UIViewRepresentable {
    @Binding var focused: Bool
    let onKey: (Character?) -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = BackspaceTextField()
        tf.onBackspace = { context.coordinator.onKey(nil) }
        tf.delegate = context.coordinator
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .allCharacters
        tf.spellCheckingType = .no
        tf.smartDashesType = .no
        tf.smartQuotesType = .no
        tf.keyboardType = .asciiCapable
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        DispatchQueue.main.async {
            if focused && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            } else if !focused && uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onKey: onKey) }

    class Coordinator: NSObject, UITextFieldDelegate {
        let onKey: (Character?) -> Void
        init(onKey: @escaping (Character?) -> Void) { self.onKey = onKey }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            // Backspace is handled by BackspaceTextField.deleteBackward()
            guard !string.isEmpty else { return false }
            for scalar in string.unicodeScalars where scalar.properties.isAlphabetic {
                onKey(Character(scalar))
            }
            return false
        }
    }
}

// MARK: - Tile View

struct TileView: View {
    let letter: Character?
    let state: LetterState
    let revealed: Bool
    let revealDelay: Double
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(bgColor)
                .animation(.easeInOut(duration: 0.25).delay(revealDelay), value: revealed)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: isSelected ? 2.5 : 2)
                )

            if let ch = letter {
                Text(String(ch).uppercased())
                    .font(.title2.bold())
                    .foregroundStyle(revealed ? .white : Color(hex: "E2E8F0"))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private var bgColor: Color {
        if !revealed { return letter == nil ? Color(hex: "1E293B") : Color(hex: "334155") }
        switch state {
        case .correct: return Color(hex: "16A34A")
        case .present: return Color(hex: "D97706")
        case .absent:  return Color(hex: "475569")
        case .unknown: return Color(hex: "1E293B")
        }
    }

    private var borderColor: Color {
        if !revealed {
            if isSelected { return .white }
            return letter == nil ? Color(hex: "334155") : Color(hex: "94A3B8")
        }
        return .clear
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
