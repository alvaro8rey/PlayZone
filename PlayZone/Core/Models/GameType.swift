import SwiftUI

enum RankingType { case time, score, streak, moves }

enum GameType: String, CaseIterable, Codable, Identifiable {
    case minesweeper = "Buscaminas"
    case sudoku      = "Sudoku"
    case game2048    = "2048"
    case memory      = "Memoria"
    case snake       = "Snake"
    case wordle      = "Wordle"
    case breakout    = "Breakout"
    case colorMatch  = "Color Mix"
    case spellingBee = "Spelling Bee"
    case nonogram    = "Nonograma"
    case lightsOut   = "Lights Out"
    case puzzle15    = "Puzzle 15"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .minesweeper: return "minesweeper"
        case .sudoku:      return "sudoku"
        case .game2048:    return "square.stack.fill"
        case .memory:      return "memory"
        case .snake:       return "snake"
        case .wordle:      return "textformat.abc"
        case .breakout:    return "breakout"
        case .colorMatch:  return "paintpalette.fill"
        case .spellingBee: return "hexagon.fill"
        case .nonogram:    return "square.grid.2x2.fill"
        case .lightsOut:   return "lightbulb.fill"
        case .puzzle15:    return "number.square.fill"
        }
    }

    var isCustomIcon: Bool {
        switch self {
        case .snake, .breakout, .minesweeper, .sudoku, .memory:
            return true
        default:
            return false
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
        case .colorMatch:  return "Mezcla RGB para igualar el color objetivo"
        case .spellingBee: return "Forma palabras de 5 letras con el panal"
        case .nonogram:    return "Rellena la cuadrícula siguiendo las pistas"
        case .lightsOut:   return "Apaga todas las luces en el menor número de movimientos"
        case .puzzle15:    return "Ordena las fichas deslizándolas al hueco vacío"
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
        case .colorMatch:  return [Color(hex: "F43F5E"), Color(hex: "8B5CF6")]
        case .spellingBee: return [Color(hex: "EAB308"), Color(hex: "92400E")]
        case .nonogram:    return [Color(hex: "6366F1"), Color(hex: "4338CA")]
        case .lightsOut:   return [Color(hex: "FBBF24"), Color(hex: "D97706")]
        case .puzzle15:    return [Color(hex: "06B6D4"), Color(hex: "0E7490")]
        }
    }

    var rankingType: RankingType {
        switch self {
        case .minesweeper, .sudoku, .memory,
             .nonogram, .breakout, .puzzle15: return .time
        case .game2048, .snake, .colorMatch,
             .spellingBee:                    return .score
        case .wordle:                         return .streak
        case .lightsOut:                      return .moves
        }
    }

    var rankingLabel: String {
        switch rankingType {
        case .time:   return "Menor tiempo"
        case .score:  return "Mayor puntuación"
        case .streak: return "Mejor racha"
        case .moves:  return "Menos movimientos"
        }
    }

    var rankingIcon: String {
        switch rankingType {
        case .time:   return "timer"
        case .score:  return "star.fill"
        case .streak: return "flame.fill"
        case .moves:  return "hand.tap.fill"
        }
    }
}
