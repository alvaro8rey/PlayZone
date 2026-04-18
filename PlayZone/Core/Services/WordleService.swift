import Foundation

actor WordleService {
    static let shared = WordleService()

    func fetchWord(length: Int) async -> String {
        if let word = try? await fetchFromAPI(length: length) {
            return word
        }
        return localWord(length: length)
    }

    func isValid(word: String, length: Int) -> Bool {
        let w = word.lowercased()
        return w.count == length && validationSet(length: length).contains(w)
    }

    // MARK: - API

    private func fetchFromAPI(length: Int) async throws -> String {
        var comps = URLComponents(string: "https://rae-api.com/api/random")!
        comps.queryItems = [
            URLQueryItem(name: "min_length", value: "\(length)"),
            URLQueryItem(name: "max_length", value: "\(length)")
        ]
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 5
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let raw = try extractWord(from: data)
        let cleaned = raw.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        guard cleaned.count == length, cleaned.allSatisfy({ $0.isLetter && $0.isASCII }) else {
            throw URLError(.badServerResponse)
        }
        return cleaned
    }

    private func extractWord(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw URLError(.cannotParseResponse)
        }
        // Object: {"palabra":"…"} or {"word":"…"}
        if let obj = json as? [String: Any] {
            for key in ["palabra", "word", "term", "texto"] {
                if let w = obj[key] as? String, !w.isEmpty { return w }
            }
        }
        // Array: ["palabra"] or [{"word":"…"}]
        if let arr = json as? [Any] {
            if let w = arr.first as? String, !w.isEmpty { return w }
            if let obj = arr.first as? [String: Any] {
                for key in ["palabra", "word", "term"] {
                    if let w = obj[key] as? String, !w.isEmpty { return w }
                }
            }
        }
        throw URLError(.cannotParseResponse)
    }

    // MARK: - Local words

    private func localWord(length: Int) -> String {
        let list = wordList(length: length)
        return list.randomElement() ?? (length == 4 ? "casa" : length == 5 ? "playa" : "ciudad")
    }

    private func validationSet(length: Int) -> Set<String> {
        Set(wordList(length: length))
    }

    private func wordList(length: Int) -> [String] {
        switch length {
        case 4: return words4
        case 5: return words5
        default: return words6
        }
    }

    // MARK: - Embedded word lists

    private let words4 = [
        "casa","mesa","pato","gato","luna","mano","pelo","boca","lago","roca",
        "vaca","pera","uvas","hoja","nube","rana","rosa","sopa","taza","vela",
        "bola","cama","dedo","faro","goma","hilo","jugo","kilo","lana","mono",
        "nido","olla","paso","queso","rama","saco","tela","uña","vara","yema",
        "zumo","alma","beso","copa","data","eje","foto","gris","isla","joya",
        "limo","mapa","nota","obra","pico","rato","sala","toro","vino","zona",
        "arco","barro","cera","duna","flor","giro","hada","imán","jaula","leña",
        "miel","nave","onda","pavo","ramo","sello","tubo","urna","vaso","yate",
        "zorro","amor","boda","cubo","diez","foca","guía","humo","idea","juez",
        "loro","mago","niño","oído","puma","ruta","sumo","tiza","usos","vida"
    ]

    private let words5 = [
        "playa","barco","campo","cielo","disco","etapa","finca","gruta","hielo","ingre",
        "juego","llama","mundo","nieve","olivo","piano","queso","radio","suelo","tigre",
        "usted","viene","yarda","zueco","aguja","blusa","cairo","delta","esfera","fuego",
        "globo","huevo","indio","jarra","limon","macho","negro","ocaso","papel","raton",
        "sobre","tumor","viaje","xenon","zorro","abeja","bolsa","coche","danza","enero",
        "fresa","gramo","hongo","ideal","jardin","leche","madre","nueve","orden","pared",
        "reina","suave","techo","urban","verano","watio","yerno","zurdo","acero","bravo",
        "calor","diente","falla","genio","habla","indice","joven","largo","marte","noche",
        "omega","pecho","queja","reino","salud","talon","verde","xerez","yunta","zafra",
        "adobe","buque","cerdo","dieta","excel","frase","guante","honor","inter","jugos"
    ]

    private let words6 = [
        "ciudad","tiempo","blanco","cabeza","dinero","espejo","frente","grande","humano","imagen",
        "jardin","lengua","manana","ningun","objeto","pueblo","quinto","riesgo","sangre","tierra",
        "ultimo","verdad","winner","yacion","zapato","activo","bonito","camino","dentro","estado",
        "fuerza","gracia","habito","inicio","juntos","lineal","medico","numero","oferta","prueba",
        "rapido","sistem","tonada","unidad","viable","xilema","yerbal","zodiac","aliado","bosque",
        "centro","delgad","empleo","figura","gloria","histor","impulso","juntar","lecion","modelo",
        "nombre","opcion","paloma","raíces","secund","tesoro","unirse","visita","yacato","zanjar",
        "albano","brillo","calles","debate","efecto","filtro","gastos","helado","idioma","juicio",
        "limite","musica","nacion","origen","paleta","receta","silaba","textur","urbano","vector",
        "weston","yodado","zambia","agente","burros","cubrir","dorado","eterno","famoso","givens"
    ]
}
