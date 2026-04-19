import Foundation

enum BeeSubmitResult: Equatable {
    case found, alreadyFound, notValid, noCenter, tooShort
}

@Observable
final class SpellingBeeGame {

    let difficulty: Difficulty
    private(set) var centerLetter: Character = "a"
    private(set) var outerLetters: [Character] = []
    private(set) var validWords:   Set<String> = []
    private(set) var foundWords:   [String]    = []
    private(set) var currentInput: String      = ""
    private(set) var lastResult:   BeeSubmitResult? = nil

    var score:      Int    { foundWords.count }
    var totalWords: Int    { validWords.count }
    var progress:   Double { totalWords > 0 ? Double(score) / Double(totalWords) : 0 }

    var rank: String {
        switch progress {
        case ..<0.05: return "Novato"
        case ..<0.20: return "Aprendiz"
        case ..<0.40: return "Aficionado"
        case ..<0.60: return "Hábil"
        case ..<0.80: return "Experto"
        case ..<1.0:  return "Maestro"
        default:       return "Gran Maestre 🐝"
        }
    }

    init(difficulty: Difficulty) {
        self.difficulty = difficulty
        generatePuzzle()
    }

    // MARK: - Input

    func addLetter(_ ch: Character) {
        currentInput.append(ch)
        lastResult = nil
    }

    func deleteLast() {
        guard !currentInput.isEmpty else { return }
        currentInput.removeLast()
        lastResult = nil
    }

    func shuffle() {
        outerLetters.shuffle()
        lastResult = nil
    }

    @discardableResult
    func submit() -> BeeSubmitResult {
        let word = currentInput.lowercased()
        currentInput = ""

        let result: BeeSubmitResult
        if word.count < 5 {
            result = .tooShort
        } else if !word.contains(centerLetter) {
            result = .noCenter
        } else if foundWords.contains(word) {
            result = .alreadyFound
        } else if !validWords.contains(word) {
            result = .notValid
        } else {
            foundWords.append(word)
            result = .found
        }
        lastResult = result
        return result
    }

    func newGame() {
        foundWords    = []
        currentInput  = ""
        lastResult    = nil
        generatePuzzle()
    }

    // MARK: - Puzzle generation

    private func generatePuzzle() {
        let words = WordLoader.load()
        let min   = difficulty.spellingBeeMinWords
        let max   = difficulty.spellingBeeMaxWords

        for _ in 0..<300 {
            guard let seed   = words.randomElement() else { continue }
            let uniqueChars  = Array(Set(seed))
            guard uniqueChars.count >= 2 else { continue }

            let center       = uniqueChars.randomElement()!
            var letterSet    = Set(uniqueChars)

            let alphabet = Array("abcdefghijlmnoprstuvz")
            while letterSet.count < 7 {
                if let l = alphabet.randomElement() { letterSet.insert(l) }
            }
            let outer = Array(letterSet.filter { $0 != center }.prefix(6))
            let full  = Set([center] + outer)

            let valid = Set(words.filter { w in
                w.contains(center) && w.allSatisfy { full.contains($0) }
            })

            if valid.count >= min && valid.count <= max {
                centerLetter = center
                outerLetters = outer
                validWords   = valid
                return
            }
        }

        // Fallback: pick common letters that always yield words
        let c: Character     = "a"
        let o: [Character]   = ["e","i","o","s","r","t"]
        let full             = Set([c] + o)
        centerLetter = c
        outerLetters = o
        validWords   = Set(words.filter { w in
            w.contains(c) && w.allSatisfy { full.contains($0) }
        })
    }
}

// MARK: - Difficulty

extension Difficulty {
    var spellingBeeMinWords: Int {
        switch self { case .easy: return 30; case .medium: return 18; case .hard: return 8 }
    }
    var spellingBeeMaxWords: Int {
        switch self { case .easy: return 1000; case .medium: return 35; case .hard: return 20 }
    }
}

// MARK: - Word loader

private enum WordLoader {
    static func load() -> [String] {
        if let url     = Bundle.main.url(forResource: "palabras", withExtension: "txt"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            let loaded = content
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.lowercased()
                         .trimmingCharacters(in: .whitespaces)
                         .folding(options: .diacriticInsensitive, locale: .current) }
                .filter { $0.count == 5 && $0.allSatisfy { $0.isLetter && $0.isASCII } }
            if !loaded.isEmpty { return loaded }
        }
        return fallback
    }

    // Small fallback in case palabras.txt is missing
    static let fallback: [String] = [
        "playa","barco","campo","cielo","tigre","oveja","cabra","llama","fresa",
        "queso","leche","trigo","pasta","salsa","crema","norte","calle","plaza",
        "libro","papel","coche","techo","suelo","pared","manta","arbol","cesta",
        "fuego","hielo","orden","salud","calor","dolor","miedo","juego","vuelo",
        "canto","baile","ritmo","enero","marzo","abril","verde","negro","claro",
        "largo","corto","bello","feliz","bravo","dulce","noble","total","civil",
        "madre","padre","novio","novia","prima","primo","joven","nieto","guapo",
        "cerdo","burro","perro","cobra","garza","tapir","cisne","potro","zorra",
        "caldo","mango","melon","limon","jamon","avena","menta","cacao","arroz",
        "monte","cerro","selva","delta","bahia","costa","llano","prado","valle",
    ]
}
