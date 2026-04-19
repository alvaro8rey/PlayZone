import SwiftUI

struct SudokuView: View {
    let difficulty: Difficulty
    @Binding var path: NavigationPath

    @State private var game: SudokuGame
    @State private var showResult = false
    @State private var isNewRecord = false
    @State private var showInfo = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var playerName = ""

    init(difficulty: Difficulty, path: Binding<NavigationPath>) {
        self.difficulty = difficulty
        self._path = path
        self._game = State(initialValue: SudokuGame(difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            if game.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Generando sudoku…")
                        .foregroundStyle(Color(hex: "94A3B8"))
                }
            } else if let err = game.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(err)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button("Reintentar") { Task { await game.load() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    statsBar
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    Divider().background(Color(hex: "334155"))
                    Spacer(minLength: 8)
                    sudokuGrid
                    Spacer(minLength: 12)
                    numberPad
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Sudoku · \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showInfo) { GameInfoSheet(game: .sudoku) }
        .task { await game.load() }
        .onChange(of: game.isComplete) { _, complete in
            if complete {
                Task {
                    await submitScore()
                    showResult = true
                }
            }
        }
        .alert("¡Sudoku Completado! 🎉", isPresented: $showResult) {
            Button("Nuevo juego") { Task { await game.load() } }
            Button("Menú") { path.removeLast(path.count) }
        } message: {
            Text(isNewRecord
                 ? "🏆 ¡Nuevo récord!  \(formattedTime(game.elapsedSeconds))  •  \(game.mistakes) errores"
                 : "Tiempo: \(formattedTime(game.elapsedSeconds))  •  Errores: \(game.mistakes)")
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack {
            Label("\(game.mistakes)", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.headline.bold())
            Spacer()
            Text(formattedTime(game.elapsedSeconds))
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(.white)
            Spacer()
            Button {
                game.toggleNotesMode()
            } label: {
                Label("Notas", systemImage: game.notesMode ? "pencil.circle.fill" : "pencil.circle")
                    .font(.subheadline.bold())
                    .foregroundStyle(game.notesMode ? Color(hex: "3B82F6") : Color(hex: "94A3B8"))
            }
        }
    }

    // MARK: - Grid

    private var sudokuGrid: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) - 16
            let cell = size / 9
            ZStack {
                // Background + thick box borders
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "1E293B"))
                    .frame(width: size, height: size)

                // Cells
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                SudokuCellView(
                                    value: game.board[row][col],
                                    notes: game.notes[row][col],
                                    isSelected: game.selected?.row == row && game.selected?.col == col,
                                    isHighlighted: game.highlightedCells.contains("\(row)_\(col)"),
                                    isOriginal: game.isOriginal(row: row, col: col),
                                    isConflict: game.isConflict(row: row, col: col),
                                    sameValue: game.selected.map { game.board[$0.row][$0.col] == game.board[row][col] && game.board[row][col] != 0 } ?? false,
                                    size: cell,
                                    rightBorder: col % 3 == 2 && col < 8,
                                    bottomBorder: row % 3 == 2 && row < 8
                                )
                                .onTapGesture { game.select(row: row, col: col) }
                            }
                        }
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: UIScreen.main.bounds.width - 16)
    }

    // MARK: - Number Pad

    private var numberPad: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(1...9, id: \.self) { num in
                    Button { game.input(number: num) } label: {
                        Text("\(num)")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(hex: "1E293B"))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            Button { game.input(number: 0) } label: {
                Label("Borrar", systemImage: "delete.left")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "334155"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func formattedTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func submitScore() async {
        let current = try? await rankingService.fetch(game: .sudoku, difficulty: difficulty)
        let previousBest = current?.first(where: { $0.playerName == playerName })?.value
        let entry = RankingEntry(playerName: playerName, game: .sudoku,
                                 difficulty: difficulty, value: game.finalMilliseconds)
        try? await rankingService.save(entry)
        isNewRecord = previousBest == nil || game.finalMilliseconds < previousBest!
    }
}

// MARK: - Cell View

struct SudokuCellView: View {
    let value: Int
    let notes: [Bool]
    let isSelected: Bool
    let isHighlighted: Bool
    let isOriginal: Bool
    let isConflict: Bool
    let sameValue: Bool
    let size: CGFloat
    let rightBorder: Bool
    let bottomBorder: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(cellBackground)
                .overlay(alignment: .trailing) {
                    if rightBorder { Rectangle().fill(Color(hex: "94A3B8")).frame(width: 2) }
                }
                .overlay(alignment: .bottom) {
                    if bottomBorder { Rectangle().fill(Color(hex: "94A3B8")).frame(height: 2) }
                }
                .border(Color(hex: "334155").opacity(0.5), width: 0.5)

            if value != 0 {
                Text("\(value)")
                    .font(.system(size: size * 0.52, weight: isOriginal ? .bold : .regular))
                    .foregroundStyle(isConflict ? .red : (isOriginal ? .white : Color(hex: "3B82F6")))
            } else if notes.contains(true) {
                noteGrid(size: size)
            }
        }
        .frame(width: size, height: size)
    }

    private var cellBackground: Color {
        if isSelected       { return Color(hex: "1E40AF").opacity(0.7) }
        if sameValue        { return Color(hex: "1E40AF").opacity(0.25) }
        if isHighlighted    { return Color(hex: "1E293B").opacity(0.9) }
        return Color(hex: "0F172A")
    }

    private func noteGrid(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { col in
                        let num = row * 3 + col
                        Text(notes[num] ? "\(num + 1)" : "")
                            .font(.system(size: size * 0.22))
                            .foregroundStyle(Color(hex: "64748B"))
                            .frame(width: size / 3, height: size / 3)
                    }
                }
            }
        }
    }
}
