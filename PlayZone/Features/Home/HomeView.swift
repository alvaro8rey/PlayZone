import SwiftUI

struct HomeView: View {
    @Binding var path: NavigationPath
    @AppStorage("playerName")      private var playerName    = ""
    @AppStorage("lastPlayedGame")  private var lastPlayedRaw = ""
    @State private var showSettings          = false
    @State private var expandedGame: GameType?    = nil
    @State private var expandedFeatured: GameType? = nil
    @State private var selectedCategory: GameCategory = .all

    private var lastPlayedGame: GameType? { GameType(rawValue: lastPlayedRaw) }

    private var filteredGames: [GameType] {
        let base = selectedCategory == .all
            ? GameType.allCases
            : GameType.allCases.filter { $0.category == selectedCategory }
        if selectedCategory == .all, let last = lastPlayedGame {
            return base.filter { $0 != last }
        }
        return base
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0F172A"), Color(hex: "1E293B")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        filterBar
                        if selectedCategory == .all, let last = lastPlayedGame {
                            featuredSection(last)
                        }
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

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(GameCategory.allCases, id: \.self) { cat in
                    let selected = selectedCategory == cat
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = cat
                            expandedGame = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.caption.bold())
                            Text(cat.rawValue)
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(selected ? .black : Color(hex: "94A3B8"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected ? Color.white : Color(hex: "1E293B"))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Featured (último jugado)

    private func featuredSection(_ game: GameType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: "94A3B8"))
                Text("Último jugado")
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: "94A3B8"))
            }
            .padding(.horizontal, 16)

            FeaturedCard(game: game, path: $path, expandedGame: $expandedFeatured,
                         onPlay: { lastPlayedRaw = game.rawValue })
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Games Grid

    private var gamesGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedCategory != .all {
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "94A3B8"))
                    Text(selectedCategory.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "94A3B8"))
                }
                .padding(.horizontal, 16)
            } else if lastPlayedGame != nil {
                HStack {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "94A3B8"))
                    Text("Todos los juegos")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "94A3B8"))
                }
                .padding(.horizontal, 16)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(filteredGames) { game in
                    GameCard(game: game, path: $path, expandedGame: $expandedGame,
                             onPlay: { lastPlayedRaw = game.rawValue })
                        .id(game)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Game Icon View (SF Symbol o PNG)

struct GameIconView: View {
    let game: GameType
    let size: CGFloat

    var body: some View {
        ZStack {
            if game.isCustomIcon {
                Image(game.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .foregroundStyle(.white)
            } else {
                Image(systemName: game.icon)
                    .font(.system(size: size * 0.85, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Featured Card

struct FeaturedCard: View {
    let game: GameType
    @Binding var path: NavigationPath
    @Binding var expandedGame: GameType?
    let onPlay: () -> Void

    private var expanded: Bool { expandedGame == game }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35)) {
                    expandedGame = expanded ? nil : game
                }
            } label: {
                ZStack(alignment: .leading) {
                    LinearGradient(colors: game.gradient,
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    HStack(spacing: 16) {
                        GameIconView(game: game, size: 52)
                            .frame(width: 70)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.rawValue)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(game.description)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            HStack(spacing: 4) {
                                Image(systemName: game.rankingIcon).font(.caption2)
                                Text(game.rankingLabel).font(.caption2)
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 2)
                        }
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.trailing, 4)
                    }
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .shadow(color: game.gradient.first!.opacity(0.4), radius: 8, y: 4)

            if expanded { difficultyPicker }
        }
    }

    private var difficultyPicker: some View {
        VStack(spacing: 8) {
            ForEach(Difficulty.allCases) { diff in
                Button { navigate(difficulty: diff) } label: {
                    HStack {
                        Image(systemName: diff.icon)
                        Text(diff.rawValue)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
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
                    Image(systemName: "chevron.right").font(.caption)
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
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func navigate(difficulty: Difficulty) {
        onPlay()
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
        case .spellingBee: path.append(Route.spellingBee(difficulty))
        case .nonogram:    path.append(Route.nonogram(difficulty))
        case .lightsOut:   path.append(Route.lightsOut(difficulty))
        case .puzzle15:    path.append(Route.puzzle15(difficulty))
        case .tetris:      path.append(Route.tetris(difficulty))
        case .mastermind:  path.append(Route.mastermind(difficulty))
        }
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: GameType
    @Binding var path: NavigationPath
    @Binding var expandedGame: GameType?
    let onPlay: () -> Void

    private var expanded: Bool { expandedGame == game }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35)) {
                    expandedGame = expanded ? nil : game
                }
            } label: {
                ZStack {
                    LinearGradient(colors: game.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 12) {
                        GameIconView(game: game, size: 38)
                            .frame(height: 40)
                        Text(game.rawValue)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(height: 22)
                        Text(game.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(height: 38)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 4) {
                            Image(systemName: game.rankingIcon).font(.caption2)
                            Text(game.rankingLabel).font(.caption2)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .shadow(color: game.gradient.first!.opacity(0.4), radius: 8, y: 4)

            if expanded {
                VStack(spacing: 8) {
                    ForEach(Difficulty.allCases) { diff in
                        Button { navigate(difficulty: diff) } label: {
                            HStack {
                                Image(systemName: diff.icon)
                                Text(diff.rawValue)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
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
                            Image(systemName: "chevron.right").font(.caption)
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
        onPlay()
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
        case .spellingBee: path.append(Route.spellingBee(difficulty))
        case .nonogram:    path.append(Route.nonogram(difficulty))
        case .lightsOut:   path.append(Route.lightsOut(difficulty))
        case .puzzle15:    path.append(Route.puzzle15(difficulty))
        case .tetris:      path.append(Route.tetris(difficulty))
        case .mastermind:  path.append(Route.mastermind(difficulty))
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
