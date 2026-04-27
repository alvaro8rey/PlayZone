import SwiftUI

enum Route: Hashable {
    case minesweeper(Difficulty)
    case sudoku(Difficulty)
    case game2048(Difficulty)
    case memory(Difficulty)
    case snake(Difficulty)
    case wordle(Difficulty)
    case breakout(Difficulty)
    case colorMatch(Difficulty)
    case spellingBee(Difficulty)
    case nonogram(Difficulty)
    case lightsOut(Difficulty)
    case puzzle15(Difficulty)
    case tetris(Difficulty)
    case mastermind(Difficulty)
    case ranking(GameType)
}

struct ContentView: View {
    @State private var path = NavigationPath()
    @AppStorage("playerName") private var playerName = ""
    @State private var showNamePrompt = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .minesweeper(let d): MinesweeperView(difficulty: d, path: $path)
                    case .sudoku(let d):      SudokuView(difficulty: d, path: $path)
                    case .game2048(let d):    Game2048View(difficulty: d, path: $path)
                    case .memory(let d):      MemoryView(difficulty: d, path: $path)
                    case .snake(let d):       SnakeView(difficulty: d, path: $path)
                    case .wordle(let d):      WordleView(difficulty: d, path: $path)
                    case .breakout(let d):    BreakoutView(difficulty: d, path: $path)
                    case .colorMatch(let d):  ColorMatchView(difficulty: d, path: $path)
                    case .spellingBee(let d): SpellingBeeView(difficulty: d, path: $path)
                    case .nonogram(let d):    NonogramView(difficulty: d, path: $path)
                    case .lightsOut(let d):   LightsOutView(difficulty: d, path: $path)
                    case .puzzle15(let d):    FifteenPuzzleView(difficulty: d, path: $path)
                    case .tetris(let d):      TetrisView(difficulty: d, path: $path)
                    case .mastermind(let d):  MastermindView(difficulty: d, path: $path)
                    case .ranking(let g):     RankingView(game: g)
                    }
                }
        }
        .onAppear {
            if playerName.isEmpty { showNamePrompt = true }
        }
        .sheet(isPresented: $showNamePrompt) {
            NamePromptView(isPresented: $showNamePrompt)
        }
    }
}

// MARK: - Name Prompt

struct NamePromptView: View {
    @Binding var isPresented: Bool
    @AppStorage("playerName") private var playerName = ""
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "6366F1"))

            Text("¡Bienvenido a PlayZone!")
                .font(.title2.bold())

            Text("¿Cómo quieres que te llamemos en el ranking?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Tu nombre", text: $draft)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .padding(.horizontal)

            Button {
                playerName = draft.trimmingCharacters(in: .whitespaces).isEmpty ? "Jugador" : draft
                isPresented = false
            } label: {
                Text("Empezar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "6366F1"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 40)
        .presentationDetents([.medium])
    }
}
