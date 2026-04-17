import SwiftUI

enum Difficulty: String, CaseIterable, Codable, Identifiable {
    case easy   = "Fácil"
    case medium = "Medio"
    case hard   = "Difícil"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var icon: String {
        switch self {
        case .easy:   return "1.circle.fill"
        case .medium: return "2.circle.fill"
        case .hard:   return "3.circle.fill"
        }
    }

    var apiKey: String {
        switch self {
        case .easy:   return "easy"
        case .medium: return "medium"
        case .hard:   return "hard"
        }
    }
}
