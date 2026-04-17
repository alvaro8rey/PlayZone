import SwiftUI

struct RankingView: View {
    let game: GameType
    @State private var selectedDifficulty: Difficulty = .easy
    @State private var entries: [RankingEntry] = []
    @State private var isLoading = false
    @Environment(\.rankingService) private var rankingService

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0F172A"), Color(hex: "1E293B")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Difficulty Picker
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
                                .background(
                                    selectedDifficulty == diff
                                    ? LinearGradient(colors: game.gradient, startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                                )
                        }
                    }
                }
                .background(Color(hex: "1E293B"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Info row
                HStack {
                    Image(systemName: game.rankingType == .time ? "timer" : "star.fill")
                    Text(game.rankingLabel)
                    Spacer()
                    Text("Top 10")
                }
                .font(.caption)
                .foregroundStyle(Color(hex: "64748B"))
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
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    RankingRow(position: index + 1, entry: entry, game: game)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Load

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

    var body: some View {
        HStack(spacing: 14) {
            // Medal
            ZStack {
                Circle()
                    .fill(medalColor)
                    .frame(width: 36, height: 36)
                Text(position <= 3 ? medalEmoji : "\(position)")
                    .font(position <= 3 ? .body : .caption.bold())
                    .foregroundStyle(.white)
            }

            // Name + date
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.playerName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Color(hex: "64748B"))
            }

            Spacer()

            // Value
            Text(entry.formattedValue)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(game.gradient.first ?? .white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "1E293B"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    private var medalColor: Color {
        switch position {
        case 1: return Color(hex: "EAB308")
        case 2: return Color(hex: "94A3B8")
        case 3: return Color(hex: "B45309")
        default: return Color(hex: "334155")
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
