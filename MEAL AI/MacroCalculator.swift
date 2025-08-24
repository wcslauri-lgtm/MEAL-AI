//
//  MacroCalculator.swift
//  MEAL AI
//
//  Created by Lauri Laitinen on 22.8.2025.
//  Updated: parannettu alias‑matching, ääkkösten tuki, painon parsinta,
//           koontiapurit (totals, per100g) ja öljyabsorptioapu.
//

import Foundation

enum MacroCalculator {

    // MARK: - Tyypit

    struct Refs {
        let cPer100: Double
        let pPer100: Double
        let fPer100: Double
    }

    struct MacroTotals {
        var carbs: Double
        var protein: Double
        var fat: Double

        mutating func add(_ c: Double, _ p: Double, _ f: Double) {
            carbs += max(0, c); protein += max(0, p); fat += max(0, f)
        }
    }

    struct MealComponent {
        let name: String     // raaka (mallin antama luokka tai ruoan nimi)
        let weightG: Double  // grammoina
    }

    // MARK: - Viitteet (/100 g)

    static let refs: [String: Refs] = [
        // Staples
        "rice":     Refs(cPer100: 28, pPer100: 2.5, fPer100: 0.5),
        "pasta":    Refs(cPer100: 30, pPer100: 5.5, fPer100: 1.5),
        "bread":    Refs(cPer100: 48, pPer100: 9.0, fPer100: 3.0),
        "potato":   Refs(cPer100: 15, pPer100: 2.0, fPer100: 0.2),
        "veg":      Refs(cPer100: 4,  pPer100: 1.5, fPer100: 0.2),
        "legumes":  Refs(cPer100: 15, pPer100: 9.0, fPer100: 1.0),
        "meat":     Refs(cPer100: 0,  pPer100: 24,  fPer100: 8),
        "poultry":  Refs(cPer100: 0,  pPer100: 26,  fPer100: 4),
        "fish":     Refs(cPer100: 0,  pPer100: 22,  fPer100: 6),
        "eggs":     Refs(cPer100: 1,  pPer100: 13,  fPer100: 11),
        "cheese":   Refs(cPer100: 1,  pPer100: 25,  fPer100: 27),
        "oil":      Refs(cPer100: 0,  pPer100: 0,   fPer100: 100),
        "sugar":    Refs(cPer100: 100,pPer100: 0,   fPer100: 0),
        "sauce":    Refs(cPer100: 8,  pPer100: 1.0, fPer100: 15),
        "fried":    Refs(cPer100: 20, pPer100: 9.0, fPer100: 15),
        "dessert":  Refs(cPer100: 40, pPer100: 5.0, fPer100: 15),
        "beverage": Refs(cPer100: 10, pPer100: 0.5, fPer100: 0.2),
        "other":    Refs(cPer100: 20, pPer100: 5,   fPer100: 5),

        // Meal‑tasoiset luokat
        "pizza":        Refs(cPer100: 27, pPer100: 11, fPer100: 10),
        "burger":       Refs(cPer100: 25, pPer100: 12, fPer100: 12),
        "fish_burger":  Refs(cPer100: 24, pPer100: 12, fPer100: 11),
        "chicken_burger": Refs(cPer100: 24, pPer100: 13, fPer100: 10),
        "veggie_burger": Refs(cPer100: 28, pPer100: 9,  fPer100: 10),
        "sandwich":     Refs(cPer100: 30, pPer100: 10, fPer100: 8),
        "club_sandwich": Refs(cPer100: 29, pPer100: 11, fPer100: 9),
        "grilled_cheese": Refs(cPer100: 32, pPer100: 12, fPer100: 14),
        "wrap":         Refs(cPer100: 28, pPer100: 11, fPer100: 9),
        "falafel_wrap": Refs(cPer100: 29, pPer100: 9,  fPer100: 10),
        "shawarma_wrap": Refs(cPer100: 25, pPer100: 12, fPer100: 10),
        "doner_wrap":   Refs(cPer100: 25, pPer100: 12, fPer100: 10),
        "quesadilla":   Refs(cPer100: 29, pPer100: 12, fPer100: 14),
        "burrito":      Refs(cPer100: 26, pPer100: 10, fPer100: 10),
        "taco":         Refs(cPer100: 20, pPer100: 10, fPer100: 9),
        "nachos":       Refs(cPer100: 51, pPer100: 8,  fPer100: 27),
        "fajitas":      Refs(cPer100: 14, pPer100: 12, fPer100: 8),

        "sushi":        Refs(cPer100: 25, pPer100: 8,  fPer100: 5),
        "sushi_roll":   Refs(cPer100: 27, pPer100: 7,  fPer100: 4),
        "nigiri":       Refs(cPer100: 23, pPer100: 9,  fPer100: 4),
        "poke":         Refs(cPer100: 23, pPer100: 11, fPer100: 7),
        "bibimbap":     Refs(cPer100: 22, pPer100: 9,  fPer100: 7),
        "kimchi_fried_rice": Refs(cPer100: 29, pPer100: 7, fPer100: 8),
        "fried_rice":   Refs(cPer100: 30, pPer100: 6,  fPer100: 8),
        "biryani":      Refs(cPer100: 28, pPer100: 8,  fPer100: 7),
        "paella":       Refs(cPer100: 23, pPer100: 9,  fPer100: 6),
        "risotto":      Refs(cPer100: 24, pPer100: 6,  fPer100: 8),
        "jambalaya":    Refs(cPer100: 21, pPer100: 8,  fPer100: 6),

        "ramen":        Refs(cPer100: 18, pPer100: 8,  fPer100: 8),
        "pho":          Refs(cPer100: 9,  pPer100: 6,  fPer100: 3),
        "laksa":        Refs(cPer100: 13, pPer100: 7,  fPer100: 5),
        "pad_thai":     Refs(cPer100: 26, pPer100: 9,  fPer100: 10),
        "chow_mein":    Refs(cPer100: 22, pPer100: 7,  fPer100: 10),
        "lo_mein":      Refs(cPer100: 22, pPer100: 7,  fPer100: 9),

        "salad_meal":   Refs(cPer100: 8,  pPer100: 4,  fPer100: 6),
        "caesar_salad": Refs(cPer100: 7,  pPer100: 7,  fPer100: 9),
        "greek_salad":  Refs(cPer100: 5,  pPer100: 3,  fPer100: 8),
        "caprese":      Refs(cPer100: 5,  pPer100: 5,  fPer100: 10),
        "tabbouleh":    Refs(cPer100: 18, pPer100: 4,  fPer100: 4),
        "buddha_bowl":  Refs(cPer100: 20, pPer100: 7,  fPer100: 8),

        "soup":         Refs(cPer100: 8,  pPer100: 4,  fPer100: 4),
        "cream_soup":   Refs(cPer100: 7,  pPer100: 3,  fPer100: 5),
        "chowder":      Refs(cPer100: 10, pPer100: 5,  fPer100: 6),
        "tomato_soup":  Refs(cPer100: 6,  pPer100: 2,  fPer100: 2),
        "minestrone":   Refs(cPer100: 9,  pPer100: 3,  fPer100: 2),
        "kalakeitto_meal": Refs(cPer100: 6, pPer100: 4, fPer100: 3),

        "porridge":     Refs(cPer100: 12, pPer100: 4,  fPer100: 3),
        "yogurt":       Refs(cPer100: 5,  pPer100: 4,  fPer100: 3),
        "kefir":        Refs(cPer100: 5,  pPer100: 3,  fPer100: 3),
        "granola":      Refs(cPer100: 60, pPer100: 9,  fPer100: 12),
        "muesli":       Refs(cPer100: 55, pPer100: 10, fPer100: 8),
        "omelette":     Refs(cPer100: 2,  pPer100: 10, fPer100: 10),
        "english_breakfast": Refs(cPer100: 10, pPer100: 9, fPer100: 11),
        "shakshuka":    Refs(cPer100: 7,  pPer100: 4,  fPer100: 6),
        "avocado_toast": Refs(cPer100: 24, pPer100: 7, fPer100: 13),
        "bagel_cc":     Refs(cPer100: 45, pPer100: 10, fPer100: 6),
        "lox_bagel":    Refs(cPer100: 32, pPer100: 13, fPer100: 7),

        "falafel":      Refs(cPer100: 30, pPer100: 8,  fPer100: 10),
        "hummus":       Refs(cPer100: 15, pPer100: 6,  fPer100: 9),
        "mezze_plate":  Refs(cPer100: 18, pPer100: 7,  fPer100: 11),
        "moussaka":     Refs(cPer100: 8,  pPer100: 6,  fPer100: 6),

        "kebab_plate":  Refs(cPer100: 18, pPer100: 13, fPer100: 14),
        "kebab_roll":   Refs(cPer100: 22, pPer100: 12, fPer100: 11),

        "french_fries": Refs(cPer100: 33, pPer100: 3,  fPer100: 12),
        "fish_and_chips": Refs(cPer100: 31, pPer100: 8, fPer100: 14),
        "schnitzel_meal": Refs(cPer100: 18, pPer100: 14, fPer100: 10),
        "chicken_parm": Refs(cPer100: 13, pPer100: 14, fPer100: 9),
        "chicken_wings": Refs(cPer100: 0,  pPer100: 17, fPer100: 14),

        "pancake":      Refs(cPer100: 28, pPer100: 7,  fPer100: 7),
        "waffle":       Refs(cPer100: 30, pPer100: 6,  fPer100: 8),
        "crepe":        Refs(cPer100: 26, pPer100: 7,  fPer100: 7),

        "cake":         Refs(cPer100: 45, pPer100: 5,  fPer100: 15),
        "cheesecake":   Refs(cPer100: 24, pPer100: 6,  fPer100: 18),
        "brownie":      Refs(cPer100: 60, pPer100: 5,  fPer100: 22),
        "cookie":       Refs(cPer100: 65, pPer100: 6,  fPer100: 20),
        "muffin":       Refs(cPer100: 48, pPer100: 6,  fPer100: 16),
        "donut":        Refs(cPer100: 47, pPer100: 6,  fPer100: 24),
        "icecream":     Refs(cPer100: 25, pPer100: 4,  fPer100: 11),
        "sorbet":       Refs(cPer100: 30, pPer100: 0,  fPer100: 0),
        "pudding":      Refs(cPer100: 20, pPer100: 3,  fPer100: 3),

        "smoothie":     Refs(cPer100: 15, pPer100: 3,  fPer100: 2),
        "milkshake":    Refs(cPer100: 18, pPer100: 4,  fPer100: 5),

        // Pasta dishes
        "lasagna":      Refs(cPer100: 14, pPer100: 9,  fPer100: 8),
        "carbonara_meal": Refs(cPer100: 24, pPer100: 9, fPer100: 10),
        "bolognese_meal": Refs(cPer100: 22, pPer100: 10, fPer100: 7),
        "pesto_pasta":  Refs(cPer100: 28, pPer100: 7,  fPer100: 12),
        "mac_and_cheese": Refs(cPer100: 24, pPer100: 9, fPer100: 10),
        "gnocchi_meal": Refs(cPer100: 27, pPer100: 6,  fPer100: 4),
        "ravioli_meal": Refs(cPer100: 28, pPer100: 9,  fPer100: 7),

        // Indian & curry variants
        "butter_chicken": Refs(cPer100: 7,  pPer100: 9,  fPer100: 9),
        "tikka_masala":   Refs(cPer100: 7,  pPer100: 10, fPer100: 8),
        "korma_chicken":  Refs(cPer100: 5,  pPer100: 9,  fPer100: 10),
        "saag_paneer":    Refs(cPer100: 5,  pPer100: 10, fPer100: 11),
        "chana_masala":   Refs(cPer100: 12, pPer100: 6,  fPer100: 3),
        "dal":            Refs(cPer100: 12, pPer100: 7,  fPer100: 3),
        "veg_curry":      Refs(cPer100: 8,  pPer100: 3,  fPer100: 6),
        "thai_green_curry": Refs(cPer100: 5, pPer100: 3, fPer100: 8),
        "thai_red_curry":   Refs(cPer100: 5, pPer100: 3, fPer100: 8),

        // Stews & chili
        "beef_stew":     Refs(cPer100: 6,  pPer100: 11, fPer100: 6),
        "goulash":       Refs(cPer100: 7,  pPer100: 9,  fPer100: 6),
        "chili_con_carne": Refs(cPer100: 10, pPer100: 10, fPer100: 7),
        "ratatouille_meal": Refs(cPer100: 5, pPer100: 2, fPer100: 4),

        // Finnish & Nordic plates
        "maksalaatikko_meal": Refs(cPer100: 19, pPer100: 7, fPer100: 8),
        "kinkkukiusaus_meal": Refs(cPer100: 11, pPer100: 8, fPer100: 7),
        "poronkäristys_meal": Refs(cPer100: 5, pPer100: 12, fPer100: 9),
        "hernekeitto_meal": Refs(cPer100: 10, pPer100: 6, fPer100: 3),
        "lanttulaatikko_meal": Refs(cPer100: 13, pPer100: 1, fPer100: 2),
        "porkkanalaatikko_meal": Refs(cPer100: 14, pPer100: 2, fPer100: 3),
        "lihapiirakka_meal": Refs(cPer100: 32, pPer100: 8, fPer100: 16),

        // Plates with sides
        "steak_plate":   Refs(cPer100: 6,  pPer100: 16, fPer100: 10),
        "chicken_plate": Refs(cPer100: 7,  pPer100: 16, fPer100: 8),
        "fish_plate":    Refs(cPer100: 6,  pPer100: 14, fPer100: 8)
    ]

    // MARK: - Alias‑kartta (FI + EN + variaatiot)

    static let aliasMap: [String: String] = [
        // — (sisältää pitkän listan; sama kuin aiemmassa versiossa) —
        // HUOM: pidä kaikki pienellä (folding käsittelee isot kirjaimet ja aksentit)
        "pizza": "pizza", "margherita": "pizza", "pepperoni pizza": "pizza", "pizza fi": "pizza",
        "burger": "burger", "hamburger": "burger", "cheeseburger": "burger",
        "fish burger": "fish_burger", "chicken burger": "chicken_burger", "veggie burger": "veggie_burger",
        "sandwich": "sandwich", "toastie": "sandwich", "panini": "sandwich", "club sandwich": "club_sandwich",
        "grilled cheese": "grilled_cheese", "voileipä": "sandwich",
        "wrap": "wrap", "tortilla wrap": "wrap", "shawarma wrap": "shawarma_wrap", "doner wrap": "doner_wrap",
        "falafel wrap": "falafel_wrap", "quesadilla": "quesadilla",
        "kebab plate": "kebab_plate", "kebab": "kebab_plate", "kebab roll": "kebab_roll", "kebab rulla": "kebab_roll",
        "burrito": "burrito", "taco": "taco", "nachos": "nachos", "fajitas": "fajitas",
        "sushi": "sushi", "sushi roll": "sushi_roll", "nigiri": "nigiri", "sashimi": "sushi",
        "poke": "poke", "poke bowl": "poke", "bibimbap": "bibimbap",
        "fried rice": "fried_rice", "kimchi fried rice": "kimchi_fried_rice",
        "biryani": "biryani", "paella": "paella", "risotto": "risotto", "jambalaya": "jambalaya",
        "ramen": "ramen", "pho": "pho", "laksa": "laksa", "pad thai": "pad_thai",
        "chow mein": "chow_mein", "lo mein": "lo_mein",
        "salad": "salad_meal", "green salad": "salad_meal", "garden salad": "salad_meal",
        "caesar salad": "caesar_salad", "greek salad": "greek_salad", "caprese": "caprese",
        "tabbouleh": "tabbouleh", "buddha bowl": "buddha_bowl",
        "soup": "soup", "tomato soup": "tomato_soup", "minestrone": "minestrone",
        "cream soup": "cream_soup", "chowder": "chowder",
        "kalakeitto": "kalakeitto_meal", "lohikeitto": "kalakeitto_meal",
        "porridge": "porridge", "oatmeal": "porridge", "kaurapuuro": "porridge",
        "yogurt": "yogurt", "jogurtti": "yogurt", "kefir": "kefir",
        "granola": "granola", "muesli": "muesli",
        "omelette": "omelette", "english breakfast": "english_breakfast", "shakshuka": "shakshuka",
        "avocado toast": "avocado_toast", "bagel with cream cheese": "bagel_cc",
        "lox bagel": "lox_bagel",
        "falafel": "falafel", "hummus": "hummus", "mezze": "mezze_plate", "mezze plate": "mezze_plate",
        "moussaka": "moussaka",
        "fries": "french_fries", "french fries": "french_fries", "ranskalaiset": "french_fries",
        "fish and chips": "fish_and_chips", "schnitzel": "schnitzel_meal", "chicken parm": "chicken_parm",
        "chicken wings": "chicken_wings",
        "pancake": "pancake", "lettu": "pancake", "crepe": "crepe", "waffle": "waffle", "vohveli": "waffle",
        "cake": "cake",  "cheesecake": "cheesecake", "brownie": "brownie",
        "cookie": "cookie", "keksi": "cookie", "muffin": "muffin", "donut": "donut",
        "ice cream": "icecream", "jäätelö": "icecream", "sorbet": "sorbet", "pudding": "pudding",
        "lasagna": "lasagna", "lasagne": "lasagna",
        "carbonara": "carbonara_meal", "bolognese": "bolognese_meal",
        "pesto pasta": "pesto_pasta", "mac and cheese": "mac_and_cheese",
        "gnocchi": "gnocchi_meal", "ravioli": "ravioli_meal",
        "butter chicken": "butter_chicken", "tikka masala": "tikka_masala",
        "chicken korma": "korma_chicken", "saag paneer": "saag_paneer",
        "chana masala": "chana_masala", "dal": "dal",
        "veg curry": "veg_curry", "thai green curry": "thai_green_curry", "thai red curry": "thai_red_curry",
        "beef stew": "beef_stew", "goulash": "goulash",
        "chili con carne": "chili_con_carne", "ratatouille": "ratatouille_meal",
        "maksalaatikko": "maksalaatikko_meal",
        "kinkkukiusaus": "kinkkukiusaus_meal",
        "poronkäristys": "poronkäristys_meal",
        "hernekeitto": "hernekeitto_meal",
        "lanttulaatikko": "lanttulaatikko_meal", "porkkanalaatikko": "porkkanalaatikko_meal",
        "lihapiirakka": "lihapiirakka_meal",
        "steak plate": "steak_plate", "chicken plate": "chicken_plate", "fish plate": "fish_plate",
        // Yleisalias‑fallbackeja (staples)
        "white rice": "rice", "brown rice": "rice", "basmati": "rice", "jasmine rice": "rice",
        "riisi": "rice", "jasmiiniriisi": "rice", "basmatiriisi": "rice", "sushiriisi": "rice",
        "pasta": "pasta", "spaghetti": "pasta", "penne": "pasta", "nuudelit": "pasta",
        "bread": "bread", "leipä": "bread", "ruisleipä": "bread", "sämpylä": "bread",
        "potato": "potato", "peruna": "potato", "muusi": "potato",
        "salad (plain)": "veg", "vihannekset": "veg", "kasvikset": "veg",
        "beans": "legumes", "kikherneet": "legumes", "linssit": "legumes",
        "beef": "meat", "liha": "meat",
        "chicken": "poultry", "kana": "poultry",
        "salmon": "fish", "lohi": "fish",
        "egg": "eggs", "munat": "eggs",
        "cheese": "cheese", "juusto": "cheese",
        "olive oil": "oil", "oliiviöljy": "oil",
        "sugar": "sugar", "sokeri": "sugar",
        "sauce": "sauce", "kastike": "sauce",
        "fried": "fried", "leivitetty": "fried",
        "dessert": "dessert", "kakku": "dessert",
        "drink": "beverage", "mehu": "beverage", "soda": "beverage"
    ]

    // Esilajiteltu alias‑avainlista (pisimmät ensin, ettei “fish” voita “fish and chips”)
    private static let _aliasKeysByLengthDesc: [String] =
        aliasMap.keys.sorted { $0.count > $1.count }

    // MARK: - Apurit

    /// Unicode‑folding + siivous (poistaa diakriitit ja erikoismerkit)
    private static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive],
                  locale: Locale.current)
         .replacingOccurrences(of: #"[^a-z0-9\s_\-]"#,
                               with: "",
                               options: .regularExpression)
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Luokan normalisointi

    static func normalizedClass(_ s: String) -> String {
        let t = fold(s)
        if let direct = aliasMap[t] { return direct }

        // Prefix/substring‑match, pisimmät aliakset ensin
        for key in _aliasKeysByLengthDesc {
            guard !key.isEmpty else { continue }
            if t.contains(key) { return aliasMap[key]! }
        }

        // Heuristiikka varalle
        if t.contains("pizza") { return "pizza" }
        if t.contains("burger") { return "burger" }
        if t.contains("wrap") || t.contains("tortilla") { return "wrap" }
        if t.contains("burrito") { return "burrito" }
        if t.contains("taco") { return "taco" }
        if t.contains("sushi") || t.contains("nigiri") { return "sushi" }
        if t.contains("poke") { return "poke" }
        if t.contains("ramen") || t.contains("pho") || t.contains("noodle") { return "ramen" }
        if t.contains("salad") || t.contains("salaat") { return "salad_meal" }
        if t.contains("soup") || t.contains("keitto") { return "soup" }
        if t.contains("pasta") || t.contains("spag") || t.contains("nuudel") { return "pasta" }
        if t.contains("rice") || t.contains("riisi") { return "rice" }
        if t.contains("bread") || t.contains("leip") { return "bread" }
        if t.contains("potato") || t.contains("perun") { return "potato" }
        if t.contains("chicken") || t.contains("kana") || t.contains("turkey") { return "poultry" }
        if t.contains("beef") || t.contains("pork") || t.contains("liha") { return "meat" }
        if t.contains("fish") || t.contains("lohi") || t.contains("tuna") || t.contains("kala") { return "fish" }
        if t.contains("egg") || t.contains("muna") { return "eggs" }
        if t.contains("cheese") || t.contains("juusto") || t.contains("rahka") { return "cheese" }
        if t.contains("oil") || t.contains("öljy") || t.contains("butter") || t.contains("voi") { return "oil" }
        if t.contains("sugar") || t.contains("soker") || t.contains("honey") || t.contains("hunaj") { return "sugar" }
        if t.contains("sauce") || t.contains("kastike") || t.contains("mayo") || t.contains("ketchup") { return "sauce" }
        if t.contains("fried") || t.contains("leivit") || t.contains("nugget") || t.contains("tempura") { return "fried" }
        if t.contains("dessert") || t.contains("kakku") || t.contains("jäätelö") || t.contains("cookie") { return "dessert" }
        if t.contains("drink") || t.contains("mehu") || t.contains("soda") || t.contains("cola") { return "beverage" }
        return "other"
    }

    // MARK: - Laskenta

    static func macros(forClass cls: String, weightG: Double) -> (Double, Double, Double) {
        let key = normalizedClass(cls)
        let r = refs[key] ?? refs["other"]!
        let factor = max(0, weightG) / 100.0
        return (r.cPer100 * factor, r.pPer100 * factor, r.fPer100 * factor)
    }

    /// Laskee makrot useasta komponentista (käyttää luokkia automaattisesti).
    static func totals(for components: [MealComponent]) -> MacroTotals {
        var tot = MacroTotals(carbs: 0, protein: 0, fat: 0)
        for comp in components {
            let (c, p, f) = macros(forClass: comp.name, weightG: comp.weightG)
            tot.add(c, p, f)
        }
        return tot
    }

    /// Muuntaa kokonaismakrot "per 100 g" jos kokonaispaino tiedossa.
    static func per100g(from totals: MacroTotals, totalWeightG: Double) -> MacroTotals {
        guard totalWeightG > 0 else { return MacroTotals(carbs: 0, protein: 0, fat: 0) }
        let factor = 100.0 / totalWeightG
        return MacroTotals(
            carbs: totals.carbs * factor,
            protein: totals.protein * factor,
            fat: totals.fat * factor
        )
    }

    /// Arvioi imeytynyt öljy friteerattuihin / leivitettyihin (voi käyttää erillisenä “oil”-komponenttina).
    static func absorbedOilEstimate(forClass cls: String, weightG: Double) -> Double {
        let key = normalizedClass(cls)
        if key == "fried" || key.contains("schnitzel") || key.contains("fish_and_chips") {
            return max(0, weightG * 0.07) // ~7 g / 100 g
        }
        return 0
    }

    // MARK: - Painon parsinta

    /// Yrittää poimia painon tekstistä: hyväksyy "250", "250 g", "250,5 g", "weight_g=250", jne.
    static func parseWeight(fromNotes notes: String?) -> Double? {
        guard let notes, !notes.isEmpty else { return nil }
        let s = notes.replacingOccurrences(of: ",", with: ".")
        let patterns = [
            #"weight_g\s*=\s*([0-9]+(?:\.[0-9]+)?)"#,
            #"(\d+(?:\.\d+)?)\s*g\b"#,
            #"(\d+(?:\.\d+)?)\b"#
        ]
        for p in patterns {
            if let r = s.range(of: p, options: .regularExpression) {
                let match = String(s[r])
                let digits = match.filter { "0123456789.".contains($0) }
                if let v = Double(digits) { return v }
            }
        }
        return nil
    }
}
