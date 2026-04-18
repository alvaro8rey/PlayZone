import SwiftUI

enum RankingType { case time, score, streak }

enum GameType: String, CaseIterable, Codable, Identifiable {
    case minesweeper = "Buscaminas"
    case sudoku      = "Sudoku"
    case game2048    = "2048"
    case memory      = "Memoria"
    case snake       = "Snake"
    case wordle      = "Wordle"
    case breakout    = "Breakout"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .minesweeper: return "scope"
        case .sudoku:      return "square.grid.3x3.fill"
        case .game2048:    return "square.stack.fill"
        case .memory:      return "rectangle.on.rectangle.angled.fill"
        case .snake:       return "arrow.triangle.turn.up.right.diamond.fill"
        case .wordle:      return "textformat.abc"
        case .breakout:    return "square.split.2x2"
        }
    }

    var description: String {
        switch self {
        case .minesweeper: return "Descubre el campo sin explotar las minas"
        case .sudoku:      return "Rellena el tablero con números del 1 al 9"
        case .game2048:    return "Combina fichas para llegar al 2048"
        case .memory:      return "Encuentra todas las parejas de cartas"
        case .snake:       return "Guía la serpiente y come sin chocar"
        case .wordle:      return "Adivina la palabra oculta en 6 intentos"
        case .breakout:    return "Destruye todos los bloques con la pelota"
        }
    }

    var gradient: [Color] {
        switch self {
        case .minesweeper: return [Color(hex: "22C55E"), Color(hex: "15803D")]
        case .sudoku:      return [Color(hex: "3B82F6"), Color(hex: "1E40AF")]
        case .game2048:    return [Color(hex: "F97316"), Color(hex: "C2410C")]
        case .memory:      return [Color(hex: "A855F7"), Color(hex: "6D28D9")]
        case .snake:       return [Color(hex: "14B8A6"), Color(hex: "0F766E")]
        case .wordle:      return [Color(hex: "F59E0B"), Color(hex: "B45309")]
        case .breakout:    return [Color(hex: "EC4899"), Color(hex: "9D174D")]
        }
    }

    var rankingType: RankingType {
        switch self {
        case .minesweeper, .sudoku, .memory: return .time
        case .game2048, .snake, .breakout:   return .score
        case .wordle:                        return .streak
        }
    }

    var rankingLabel: String {
        switch rankingType {
        case .time:   return "Menor tiempo"
        case .score:  return "Mayor puntuación"
        case .streak: return "Mejor racha"
        }
    }
}
