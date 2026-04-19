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
            // Animals
            "gato","pato","rata","rana","toro","vaca","puma","foca","loro","sapo",
            "buho","mula","lobo","gamo","alce","poni","reno","cria","orca","mico",
            "leon","mono","aves","buey","pavo","erizo","topo","osez","potra","fais",
            "lira","oson","titi","mulo","buey","foca","puma",
            // Food & drink
            "pera","uvas","sopa","vino","zumo","miel","coco","lima","kiwi","higo",
            "cafe","masa","flan","nata","taco","tapa","haba","yema","cena","nuez",
            "pina","soja","maiz","panes","atun","jugo","cana","lomo","pate","rabo",
            "seta","tofu","moka","sidra","hago","soja","kaki",
            // Body
            "mano","pelo","boca","piel","dedo","cara","oido","unas","codo",
            "ceja","seno","nuca","talon","vena","pata","unas","iris","sien","tibi",
            "lomo","seno","pupa",
            // Home & objects
            "casa","mesa","cama","saco","vaso","copa","tubo","olla","sofa","taza",
            "vela","faro","hilo","lana","nido","rama","tela","vara","bola","losa",
            "pila","tele","llave","foco","caja","cubo","base","fila","hoja","cuna",
            "mapa","lupa","redes","pala","bano","pozo","muro","viga","teja","sino",
            "pomo","lona","bote","tapa","imán",
            // Nature & Abstract
            "luna","lago","roca","hoja","nube","rosa","arco","flor","onda","isla",
            "lodo","lava","pico","duna","limo","pozo","yuca","brea","lena","poza",
            "amor","boda","humo","idea","mago","ruta","tiza","vida","foto","joya",
            "obra","sala","zona","ropa","seda","tema","tono","tipo","peso","paso",
            "azul","gris","frio","malo","buen","real","rudo","fijo","fiel","util",
            "alba","cima","vado","seto","pino","maro","ríos","cabo","mina","fase"
        ]

        private let words5 = [
            // Animals & Nature
            "tigre","oveja","cabra","llama","cobra","garza","panda","tapir","cisne",
            "burro","cerdo","perro","zorra","cebra","potro","ganso","bison","raton",
            "koala","morsa","pulpo","pajaro","hiena","lince","tucan","coral","abeja",
            "playa","campo","monte","cerro","selva","delta","norte","oeste","calle",
            "plaza","villa","valle","bahia","costa","llano","prado","otono","cauce",
            "gruta","oasis","clima","suelo","rocas","canal","bosque","nubes","rayos",
            "nieve","flora","fauna","punta","ester","perla","arena",
            // Food & Objects
            "queso","leche","trigo","pollo","fresa","limon","melon","mango","avena",
            "pasta","caldo","salsa","crema","menta","cacao","arroz","jamon","oliva",
            "huevo","fruta","donas","pizza","peras","alino","barco","coche","techo",
            "pared","manta","libro","bolsa","radio","papel","reloj","piano","carro",
            "barca","boton","silla","banco","arbol","llave","marco","cesta","clavo",
            "farol","toldo","cable","disco","mando","copia","maleta","telar","bolso",
            "peine","jarra","globo","sobre","termo","llano","funda","tecla","video",
            // People & Abstract
            "madre","padre","novio","novia","prima","primo","sabio","viejo","nuevo",
            "gordo","flaco","guapo","linda","joven","nieto","nieta","barba","torso",
            "brazo","pecho","labio","nariz","oreja","mente","hueso","punon","muslo",
            "mundo","cielo","fuego","hielo","orden","salud","reino","calor","dolor",
            "miedo","juego","vuelo","sueno","canto","baile","ritmo","fondo","turno",
            "negro","verde","claro","rubio","sucio","largo","corto","ancho","bello",
            "feliz","bravo","dulce","mejor","total","digno","civil","noble","cruel",
            "actor","autor","poeta","socio","dueño","libre","justo","falso"
        ]

        private let words6 = [
            // Society & People
            "ciudad","humano","pueblo","jardin","barrio","virgen","vecino","medico",
            "marino","romano","pirata","safari","hombre","esposo","abuelo","amigo",
            "policia","adulto","sujeto","social","familia","pareja","obrero","turista",
            "musico","jinete","fiscal","agente","piloto","pastor","monje","chofer",
            "pintor","reinas","sabios","héroe","enlace",
            // Nature & Science
            "bosque","tierra","viento","lluvia","hierba","halcon","volcan","laguna",
            "jungla","salmon","trucha","vibora","pajaro","nutria","trueno","cometa",
            "planeta","animal","ardilla","ballena","conejo","insecto","galaxia",
            "hierro","cuarzo","carbon","petrol","niebla","clavel","jazmín","huerto",
            "cuevas","prados","buitre",
            // Objects & Home
            "camisa","zapato","helado","flauta","tomate","sarten","tocino","sandia",
            "pepino","taller","tejado","templo","teatro","tronco","tienda","cocina",
            "pasillo","puerta","nevera","canela","azucar","harina","frasco","espejo",
            "figura","filtro","modelo","objeto","parque","pelota","postal","titulo",
            "vuelta","zocalo","zafiro","rancho","rincon","ropero","camara","cuadro",
            "tarjeta","pincel","estatua","maleta","puente","fuente","abrigo","anillo",
            "balcón","botella","cepillo","cuadros","mueble","buzón","sábana","toalla",
            // Abstract & States
            "verdad","fuerza","gracia","inicio","riesgo","unidad","visita","centro",
            "debate","efecto","gloria","idioma","limite","nacion","origen","receta",
            "urbano","dorado","eterno","famoso","futuro","genero","juicio","nombre",
            "placer","tesoro","imagen","camino","dentro","estado","dinero","semana",
            "paloma","crisis","chiste","duende","blanco","brillo","casino","musica",
            "rapido","motivo","sonido","terror","torneo","sirena","sereno","novela",
            "hambre","escena","fresco","marcha","suerte","pureza","logica","humild",
            "alegre","astuto","bronce","clavel","dibujo","empleo","estilo","fiesta",
            "anhelo","asunto","cambio","pánico","queja","razón","triunf","valor"
        ]
}
