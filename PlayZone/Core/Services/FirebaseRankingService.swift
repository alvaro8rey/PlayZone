// MARK: - Firebase Ranking Service
//
// HOW TO ENABLE FIREBASE RANKINGS
// ─────────────────────────────────
// 1. In Xcode → File → Add Package Dependencies
//    URL: https://github.com/firebase/firebase-ios-sdk
//    Products: FirebaseFirestore, FirebaseAnalytics
//
// 2. Create a Firebase project at console.firebase.google.com
//    Add an iOS app with Bundle ID: ARG.PlayZone
//    Download GoogleService-Info.plist and add it to the PlayZone target
//
// 3. In Firestore console → Rules, allow read/write (or set up auth)
//
// 4. In PlayZoneApp.swift, replace:
//      let ranking: any RankingService = LocalRankingService.shared
//    with:
//      let ranking: any RankingService = FirebaseRankingService()
//    and uncomment the FirebaseApp.configure() call.
//
// 5. Uncomment the code below (remove the #if false / #endif wrapper).

import FirebaseCore
import FirebaseFirestore

final class FirebaseRankingService: RankingService {
    private lazy var db = Firestore.firestore()
    private let col = "rankings"

    func save(_ entry: RankingEntry) async throws {
        let ref = db.collection(col).document(entry.id)
        try await ref.setData([
            "playerName": entry.playerName,
            "game":       entry.game,
            "difficulty": entry.difficulty,
            "value":      entry.value,
            "date":       Timestamp(date: entry.date)
        ])
    }

    func fetch(game: GameType, difficulty: Difficulty) async throws -> [RankingEntry] {
        // No .order() in the query — avoids requiring a Firestore composite index.
        // Sorting is done in Swift after fetching.
        let snap = try await db.collection(col)
            .whereField("game",       isEqualTo: game.rawValue)
            .whereField("difficulty", isEqualTo: difficulty.rawValue)
            .getDocuments()

        let entries: [RankingEntry] = snap.documents.compactMap { doc in
            let d = doc.data()
            guard let name = d["playerName"] as? String,
                  let g    = d["game"]       as? String,
                  let diff = d["difficulty"] as? String,
                  let val  = d["value"]      as? Int,
                  let ts   = d["date"]       as? Timestamp
            else { return nil }
            return RankingEntry(id: doc.documentID, playerName: name,
                                game: g, difficulty: diff,
                                value: val, date: ts.dateValue())
        }

        let sorted = game.rankingType == .score
            ? entries.sorted { $0.value > $1.value }
            : entries.sorted { $0.value < $1.value }

        return Array(sorted.prefix(10))
    }
}
