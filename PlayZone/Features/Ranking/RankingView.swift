import SwiftUI

struct RankingView: View {
    let game: GameType
    @State private var selectedDifficulty: Difficulty = .easy
    @State private var entries: [RankingEntry] = []
    @State private var isLoading = false
    @Environment(\.rankingService) private var rankingService
    @AppStorage("playerName") private var currentPlayer = ""

    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()

            VStack(spacing: 0) {
                difficultyPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                infoRow
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if entries.isEmpty {
                    emptyState
                } else {
                    rankingList
                }
            }
        }
        .navigationTitle("Ranking · \(game.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadRanking() }
    }

    // MARK: - Difficulty Picker

    private var difficultyPicker: some View {
        HStack(spacing: 0) {
            ForEach(Difficulty.allCases) { diff in
                Button {
                    selectedDifficulty = diff
                    Task { await loadRanking() }
                } label: {
                    Text(diff.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(selectedDifficulty == diff ? .white : Color(hex: "64748B"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedDifficulty == diff ? game.color : Color.clear)
                }
            }
        }
        .background(Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Info Row

    private var infoRow: some View {
        HStack {
            Image(systemName: game.rankingIcon)
            Text(game.rankingLabel)
            Spacer()
            if let pos = myPosition {
                Text("Tu posición: #\(pos)")
                    .fontWeight(.semibold)
                    .foregroundStyle(game.color)
            }
        }
        .font(.caption)
        .foregroundStyle(Color(hex: "64748B"))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "trophy")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "334155"))
            Text("Sin puntuaciones aún")
                .font(.headline)
                .foregroundStyle(Color(hex: "64748B"))
            Text("¡Juega y sé el primero en el ranking!")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "475569"))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - List

    private var rankingList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        RankingRow(
                            position: index + 1,
                            entry: entry,
                            game: game,
                            isCurrentPlayer: entry.playerName == currentPlayer
                        )
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .onAppear {
                scrollToPlayer(proxy: proxy)
            }
            .onChange(of: entries) { _, _ in
                scrollToPlayer(proxy: proxy)
            }
        }
    }

    // MARK: - Helpers

    private var myPosition: Int? {
        guard let idx = entries.firstIndex(where: { $0.playerName == currentPlayer })
        else { return nil }
        return idx + 1
    }

    private func scrollToPlayer(proxy: ScrollViewProxy) {
        guard let entry = entries.first(where: { $0.playerName == currentPlayer }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation { proxy.scrollTo(entry.id, anchor: .center) }
        }
    }

    private func loadRanking() async {
        isLoading = true
        entries = (try? await rankingService.fetch(game: game, difficulty: selectedDifficulty)) ?? []
        isLoading = false
    }
}

// MARK: - Row

struct RankingRow: View {
    let position: Int
    let entry: RankingEntry
    let game: GameType
    let isCurrentPlayer: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(medalColor)
                    .frame(width: 36, height: 36)
                Text(position <= 3 ? medalEmoji : "\(position)")
                    .font(position <= 3 ? .body : .caption.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.playerName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if isCurrentPlayer {
                        Text("TÚ")
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.yellow)
                            .clipShape(Capsule())
                    }
                }
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Color(hex: "64748B"))
            }

            Spacer()

            Text(entry.formattedValue)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(game.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrentPlayer ? Color(hex: "1E3A5F") : Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isCurrentPlayer ? Color.yellow.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    private var medalColor: Color {
        switch position {
        case 1: return Color(hex: "EAB308")
        case 2: return Color(hex: "94A3B8")
        case 3: return Color(hex: "B45309")
        default: return isCurrentPlayer ? Color(hex: "1E40AF") : Color(hex: "334155")
        }
    }

    private var medalEmoji: String {
        switch position {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(position)"
        }
    }
}
