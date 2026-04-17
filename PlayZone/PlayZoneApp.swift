import SwiftUI

@main
struct PlayZoneApp: App {
    let ranking: any RankingService = FirebaseRankingService()

    init() {
        FirebaseApp.configure()
    }

    @AppStorage("playerName") var playerName: String = ""

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.rankingService, ranking)
                .environment(\.playerName, playerName)
        }
    }
}

// MARK: - Environment Keys

private struct RankingServiceKey: EnvironmentKey {
    static let defaultValue: any RankingService = LocalRankingService.shared
}

private struct PlayerNameKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    var rankingService: any RankingService {
        get { self[RankingServiceKey.self] }
        set { self[RankingServiceKey.self] = newValue }
    }
    var playerName: String {
        get { self[PlayerNameKey.self] }
        set { self[PlayerNameKey.self] = newValue }
    }
}
