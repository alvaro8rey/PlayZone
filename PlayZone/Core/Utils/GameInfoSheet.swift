import SwiftUI

// MARK: - Info sheet

struct GameInfoSheet: View {
    let game: GameType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    HStack(spacing: 14) {
                        Image(systemName: game.icon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: game.gradient,
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing))
                        Text(game.rawValue)
                            .font(.title.bold())
                    }
                    .padding(.top, 4)

                    infoSection(title: "Cómo jugar",
                                icon:  "gamecontroller.fill",
                                color: Color(hex: "3B82F6"),
                                text:  game.rulesText)

                    infoSection(title: "Clasificación",
                                icon:  "trophy.fill",
                                color: Color(hex: "EAB308"),
                                text:  game.rankingText)
                }
                .padding(20)
            }
            .navigationTitle("Información")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func infoSection(title: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline.bold())
            }
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Content per game

extension GameType {

    var rulesText: String {
        switch self {
        case .minesweeper:
            return "Toca las casillas para descubrirlas. Los números indican cuántas minas hay en las celdas adyacentes. Mantén pulsado (o activa la bandera) para marcar una mina sospechosa. ¡No toques ninguna mina!"
        case .sudoku:
            return "Rellena la cuadrícula 9×9 con los dígitos del 1 al 9. Cada fila, columna y subcuadrícula 3×3 debe contener todos los dígitos exactamente una vez. Selecciona una celda vacía y elige el número."
        case .game2048:
            return "Desliza el tablero en cualquier dirección para mover todas las fichas. Cuando dos fichas con el mismo número chocan, se fusionan sumando su valor. ¡Llega a la ficha 2048 para ganar!"
        case .memory:
            return "Voltea dos cartas a la vez buscando parejas iguales. Si las dos cartas coinciden, se quedan descubiertas. Si no, se voltean de nuevo. ¡Encuentra todas las parejas lo antes posible!"
        case .snake:
            return "Desliza en la dirección que quieras para guiar a la serpiente. Come la comida para crecer y sumar puntos. ¡No choques contra las paredes ni contra tu propio cuerpo!"
        case .wordle:
            return "Tienes 6 intentos para adivinar la palabra oculta. Tras cada intento las letras se colorean: 🟩 verde = letra correcta en posición correcta · 🟨 amarillo = letra en la palabra pero en otra posición · ⬛ gris = letra que no está en la palabra."
        case .breakout:
            return "Arrastra el dedo para mover la paleta. La pelota rebota contra los bloques destruyéndolos. Si la pelota cae por debajo de la paleta, pierdes una vida. ¡Destruye todos los bloques para ganar!"
        case .colorMatch:
            return "Cada ronda se muestra un color objetivo. Ajusta los sliders de Rojo, Verde y Azul para intentar igualarlo. Cuando estés listo, pulsa Confirmar. Cuanto más cerca estés del color original, más puntos recibirás (máximo 100 por ronda)."
        case .spellingBee:
            return "Forma palabras de exactamente 5 letras usando solo los 7 caracteres del panal. La letra central (dorada) debe aparecer en cada palabra. Puedes usar la misma letra más de una vez. Toca o arrastra hasta el hexágono deseado y suelta para seleccionarlo."
        case .nonogram:
            return "Rellena las casillas de la cuadrícula siguiendo las pistas numéricas de filas y columnas. Los números indican grupos consecutivos de casillas rellenas separados por al menos una vacía. Toca para rellenar, toca de nuevo para marcar con X (descartada), toca una tercera vez para vaciar."
        case .lightsOut:
            return "Toca cualquier celda para cambiar su estado (encendida/apagada) junto con el de sus vecinas arriba, abajo, izquierda y derecha. El objetivo es apagar todas las luces. El puzzle siempre tiene solución. Cuantos menos movimientos uses, mejor."
        case .puzzle15:
            return "Desliza las fichas numeradas al hueco vacío para ordenarlas de menor a mayor de izquierda a derecha y de arriba a abajo, dejando el hueco en la última posición. Solo puedes mover fichas adyacentes al hueco. Complétalo lo más rápido posible."
        case .tetris:
            return "Las piezas caen desde arriba. Usa los botones para moverlas izquierda/derecha, rotarlas o bajarlas. Pulsa la flecha doble para dejarlas caer al instante. Cuando una fila se rellena completamente, desaparece y sumas puntos. ¡El juego termina si las piezas llegan arriba!"
        }
    }

    var rankingText: String {
        switch self {
        case .minesweeper:
            return "Se registra el tiempo total que tardas en completar el tablero sin explotar ninguna mina. Gana quien emplee menos tiempo. Tu mejor marca se guarda por cada nivel de dificultad."
        case .sudoku:
            return "Se registra el tiempo que tardas en resolver el puzzle completo. Cuanto menos tardes, mejor será tu posición en el ranking. Tu mejor marca se guarda por dificultad."
        case .game2048:
            return "La puntuación es la suma de todas las fusiones realizadas durante la partida. Cuanto mayor sea tu puntuación al terminar, mejor tu posición. Se guarda la puntuación más alta por dificultad."
        case .memory:
            return "Se registra el tiempo que tardas en encontrar todas las parejas. Menos tiempo = mejor posición. Tu mejor marca se guarda por dificultad."
        case .snake:
            return "La puntuación equivale al número de comidas recolectadas. Cuantas más comas antes de morir, mejor tu posición. Se guarda la puntuación más alta por dificultad."
        case .wordle:
            return "El ranking es por racha: número de palabras adivinadas consecutivamente sin fallar. Si fallas una partida, la racha vuelve a 0. Se guarda la racha máxima por dificultad (longitud de palabra)."
        case .breakout:
            return "Se registra el tiempo total que tardas en destruir todos los bloques. El tiempo sigue acumulándose aunque pierdas vidas. Gana quien complete el tablero más rápido."
        case .colorMatch:
            return "La puntuación total es la suma de los puntos obtenidos en cada ronda (máximo 100 por ronda). Cuanto más se parezca tu mezcla al color objetivo, más puntos. Se guarda la puntuación total más alta por dificultad."
        case .spellingBee:
            return "El ranking es el número máximo de palabras distintas encontradas en una misma partida. Cuantas más palabras encuentres antes de iniciar un nuevo juego, mejor tu posición. Se guarda el récord por dificultad."
        case .nonogram:
            return "Se registra el tiempo total que tardas en resolver el nonograma completo. Cuanto menos tardes, mejor tu posición. Tu mejor marca se guarda por nivel de dificultad (5×5, 10×10, 15×15)."
        case .lightsOut:
            return "Se registra el número de movimientos que necesitas para apagar todas las luces. Cuantos menos movimientos, mejor tu posición. Tu mejor marca se guarda por tamaño de tablero (3×3, 5×5, 7×7)."
        case .puzzle15:
            return "Se registra el tiempo total que tardas en ordenar todas las fichas correctamente. Cuanto menos tardes, mejor tu posición. Tu mejor marca se guarda por dificultad (8, 15 y 24-puzzle)."
        case .tetris:
            return "La puntuación depende de cuántas líneas completes a la vez: 1 línea = 100 pts, 2 = 300, 3 = 500, 4 (Tetris) = 800. Todo multiplicado por el nivel actual. Se guarda la puntuación más alta por dificultad."
        }
    }
}
