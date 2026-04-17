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
        let isScore = GameType(rawValue: entry.game)?.rankingType == .score

        // Query only by game+difficulty (no composite index needed),
        // then filter by playerName in Swift to find the existing document.
        let snap = try await db.collection(col)
            .whereField("game",       isEqualTo: entry.game)
            .whereField("difficulty", isEqualTo: entry.difficulty)
            .getDocuments()

        let playerDocs = snap.documents.filter {
            ($0.data()["playerName"] as? String) == entry.playerName
        }

        let payload: [String: Any] = [
            "playerName": entry.playerName,
            "game":       entry.game,
            "difficulty": entry.difficulty,
            "value":      entry.value,
            "date":       Timestamp(date: entry.date)
        ]

        if let best = playerDocs.first {
            let currentValue = best.data()["value"] as? Int ?? 0
            let isBetter = isScore ? entry.value > currentValue : entry.value < currentValue
            if isBetter {
                // Update best document and delete any extra duplicates
                try await best.reference.setData(payload)
                for dup in playerDocs.dropFirst() { try await dup.reference.delete() }
            }
        } else {
            try await db.collection(col).document(entry.id).setData(payload)
        }
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

        // Deduplicate: keep only the best entry per player
        let deduped = Dictionary(grouping: entries, by: \.playerName)
            .values
            .compactMap { group -> RankingEntry? in
                game.rankingType == .score
                    ? group.max(by: { $0.value < $1.value })
                    : group.min(by: { $0.value > $1.value })
            }

        return game.rankingType == .score
            ? deduped.sorted { $0.value > $1.value }
            : deduped.sorted { $0.value < $1.value }
    }
}
