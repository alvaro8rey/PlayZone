import Foundation

actor WordleService {
    static let shared = WordleService()

    func fetchWord(length: Int) async -> String {
        let word = localWord(length: length)
        print("[WordleService] 📖 Local → \"\(word)\" (length \(length))")
        return word
    }

    func isValid(word: String, length: Int) -> Bool {
        let w = word.lowercased()
        return w.count == length && validationSet(length: length).contains(w)
    }

    // MARK: - Local words

    private func localWord(length: Int) -> String {
        wordList(length: length).randomElement()!
    }

    private func validationSet(length: Int) -> Set<String> {
        Set(wordList(length: length))
    }

    private func wordList(length: Int) -> [String] {
        switch length {
        case 4:  return words4
        case 5:  return words5
        default: return words6
        }
    }

    // MARK: - Curated word lists — common everyday Spanish, no obscure forms

    private let words4 = [
        // Animals (4 letters)
        "gato","pato","rata","rana","toro","vaca","puma","foca","loro","sapo",
        "buho","mula","lobo","gamo","alce","poni","reno","cria","orca","mico",
        // Food & drink
        "pera","uvas","sopa","vino","zumo","miel","coco","lima","kiwi","higo",
        "cafe","masa","flan","nata","taco","tapa","haba","yema","cena","nuez",
        // Body
        "mano","pelo","boca","piel","dedo","cara","oido","unas","codo",
        // Home & objects
        "casa","mesa","cama","saco","vaso","copa","tubo","olla","sofa","taza",
        "vela","faro","hilo","lana","nido","rama","tela","vara","bola","losa",
        // Nature
        "luna","lago","roca","hoja","nube","rosa","arco","flor","onda","isla",
        "lodo","lava","pico","duna","limo","pozo","yuca","brea","lena","poza",
        // Abstract & common
        "amor","boda","cubo","humo","idea","mago","ruta","tiza","vida","foto",
        "joya","mapa","nota","obra","sala","zona","ropa","seda","tema","tono",
        "tipo","peso","paso","pena","pero","pino","piso","poco","polo","rico",
        "rojo","tren","trio","vena","viga","vivo","yoga","palo","odio","ocio",
    ]

    private let words5 = [
        // Animals (5 letters)
        "tigre","oveja","cabra","llama","cobra","garza","panda","tapir","cisne",
        "burro","cerdo","perro","zorra","cebra","potro","ganso","bisón",
        // Food & drink
        "queso","leche","trigo","pollo","fresa","limon","melon","mango","avena",
        "pasta","caldo","salsa","crema","menta","cacao","arroz","jamon","oliva",
        "nieve","tamal","carne",
        // People & body
        "madre","padre","novio","novia","prima","primo","sabio","viejo","nuevo",
        "gordo","flaco","guapo","linda","joven","nieto","nieta","barba","torso",
        // Places & nature
        "playa","campo","monte","cerro","selva","delta","norte","oeste","calle",
        "plaza","villa","valle","bahia","costa","llano","prado","otono","cauce",
        // Home & objects
        "barco","coche","techo","suelo","pared","manta","libro","bolsa","radio",
        "papel","reloj","piano","carro","barca","boton","silla","banco","arbol",
        "hueso","llave","marco","cesta","clavo","farol","toldo",
        // Abstract & common
        "mundo","cielo","fuego","hielo","orden","salud","reino","calor","dolor",
        "miedo","juego","vuelo","sueno","canto","baile","ritmo","fondo","turno",
        "rasgo","logro","enero","marzo","abril","junio","julio","negro","verde",
        "claro","rubio","sucio","largo","corto","ancho","bello","feliz","bravo",
        "dulce","mejor","cenit","total","digno","civil","noble","cruel",
    ]

    private let words6 = [
        // People & social
        "ciudad","humano","pueblo","jardin","barrio","virgen","vecino","medico",
        "marino","romano","pirata","safari","hombre",
        // Time & calendar
        "martes","jueves","sabado","agosto","verano","tiempo","siesta",
        // Nature & animals
        "bosque","tierra","viento","lluvia","hierba","halcon","volcan","laguna",
        "jungla","salmon","trucha","vibora","pajaro","nutria",
        // Body & health
        "cabeza","lengua","frente","sangre","cuerpo","pulmon",
        // Food & home
        "camisa","zapato","helado","flauta","tomate","sarten","tocino","sandia",
        "pepino","taller","tejado","templo","teatro","tronco","tienda",
        // Objects & places
        "espejo","figura","filtro","modelo","objeto","parque","pelota","postal",
        "titulo","vuelta","zocalo","zafiro","rancho","rincon","ropero",
        // Abstract & qualities
        "verdad","fuerza","gracia","inicio","riesgo","unidad","visita","centro",
        "debate","efecto","gloria","idioma","limite","nacion","origen","receta",
        "urbano","dorado","eterno","famoso","futuro","genero","juicio","nombre",
        "placer","tesoro","imagen","camino","dentro","estado","dinero","semana",
        "paloma","crisis","chiste","duende","blanco","brillo","casino","musica",
        "rapido","motivo","sonido","terror","torneo","sirena","sereno","novela",
        "hambre","escena","fresco","marcha",
    ]
}
