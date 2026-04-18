import SwiftUI

struct HomeView: View {
    @Binding var path: NavigationPath
    @AppStorage("playerName") private var playerName = ""
    @State private var showSettings = false
    @State private var expandedGame: GameType? = nil

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0F172A"), Color(hex: "1E293B")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 28) {
                        header
                        gamesGrid
                    }
                    .padding(.bottom, 32)
                }
                .onChange(of: expandedGame) { _, game in
                    guard let game else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(game, anchor: .center)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PlayZone")
                    .font(.largeTitle.bold())
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "94A3B8")],
                                                   startPoint: .leading, endPoint: .trailing))
                Text("Hola, \(playerName) 👋")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "94A3B8"))
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "94A3B8"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Games Grid

    private var gamesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(GameType.allCases) { game in
                GameCard(game: game, path: $path, expandedGame: $expandedGame)
                    .id(game)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: GameType
    @Binding var path: NavigationPath
    @Binding var expandedGame: GameType?

    private var expanded: Bool { expandedGame == game }

    var body: some View {
        VStack(spacing: 0) {
            // Card front
            Button {
                withAnimation(.spring(response: 0.35)) {
                    expandedGame = expanded ? nil : game
                }
            } label: {
                ZStack {
                    LinearGradient(colors: game.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

                    VStack(spacing: 10) {
                        Image(systemName: game.icon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(game.rawValue)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(game.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Ranking badge
                        HStack(spacing: 4) {
                            Image(systemName: game.rankingType == .time ? "timer" : "star.fill")
                                .font(.caption2)
                            Text(game.rankingLabel)
                                .font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .shadow(color: game.gradient.first!.opacity(0.4), radius: 8, y: 4)

            // Expanded difficulty picker
            if expanded {
                VStack(spacing: 8) {
                    ForEach(Difficulty.allCases) { diff in
                        Button {
                            navigate(difficulty: diff)
                        } label: {
                            HStack {
                                Image(systemName: diff.icon)
                                Text(diff.rawValue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(diff.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(diff.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    Button {
                        path.append(Route.ranking(game))
                        expandedGame = nil
                    } label: {
                        HStack {
                            Image(systemName: "trophy.fill")
                            Text("Ver Ranking")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.yellow.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(10)
                .background(Color(hex: "1E293B"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func navigate(difficulty: Difficulty) {
        expandedGame = nil
        switch game {
        case .minesweeper: path.append(Route.minesweeper(difficulty))
        case .sudoku:      path.append(Route.sudoku(difficulty))
        case .game2048:    path.append(Route.game2048(difficulty))
        case .memory:      path.append(Route.memory(difficulty))
        case .snake:       path.append(Route.snake(difficulty))
        case .wordle:      path.append(Route.wordle(difficulty))
        case .breakout:    path.append(Route.breakout(difficulty))
        case .colorMatch:  path.append(Route.colorMatch(difficulty))
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("playerName") private var playerName = ""
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Jugador") {
                    TextField("Nombre", text: $draft)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        playerName = draft.isEmpty ? playerName : draft
                        dismiss()
                    }
                }
            }
            .onAppear { draft = playerName }
        }
    }
}
