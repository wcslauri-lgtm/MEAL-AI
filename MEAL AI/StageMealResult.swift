import Foundation

// Yhden ruokaerän tietue (arvot voivat puuttua -> optional)
struct MealFoodItem: Codable {
    var name: String
    var carbs_g: Double?
    var protein_g: Double?
    var fat_g: Double?
    var confidence: Double?
    var notes: String?
    // Premiumissa paino voi tulla joko notes: "weight_g=..." tai suoraan:
    var estimated_weight_g: Double?
}

// Makrojen summa
struct MealTotals: Codable {
    var carbs_g: Double
    var protein_g: Double
    var fat_g: Double

    static let zero = MealTotals(carbs_g: 0, protein_g: 0, fat_g: 0)
}

// Koko paluurakenne
struct StageMealResult: Codable {
    struct Analysis: Codable {
        var foods: [MealFoodItem]
        var totals: MealTotals
        // Premiumissa voidaan raportoida myös per 100 g
        var per100g: MealTotals?

        // SALLIVA DEKOODAUS
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // foods puuttuu -> tyhjä lista
            self.foods = (try? c.decode([MealFoodItem].self, forKey: .foods)) ?? []
            // totals puuttuu -> nollat
            self.totals = (try? c.decode(MealTotals.self, forKey: .totals)) ?? .zero
            // per100g voi puuttua
            self.per100g = try? c.decode(MealTotals.self, forKey: .per100g)
        }

        init(foods: [MealFoodItem], totals: MealTotals, per100g: MealTotals? = nil) {
            self.foods = foods
            self.totals = totals
            self.per100g = per100g
        }
    }

    var analysis: Analysis
    // Selitystekstit voivat puuttua -> tyhjä merkkijono
    var reasoning: String
    var selvitys: String
    // “tulos” voi puuttua -> ei haittaa UI:lle
    var tulos: [String:String]?

    // SALLIVA DEKOODAUS
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.analysis = (try? c.decode(Analysis.self, forKey: .analysis))
            ?? Analysis(foods: [], totals: .zero, per100g: nil)
        self.reasoning = (try? c.decode(String.self, forKey: .reasoning)) ?? ""
        self.selvitys  = (try? c.decode(String.self, forKey: .selvitys))  ?? ""
        self.tulos     = try? c.decode([String:String].self, forKey: .tulos)
    }

    init(analysis: Analysis, reasoning: String = "", selvitys: String = "", tulos: [String:String]? = nil) {
        self.analysis = analysis
        self.reasoning = reasoning
        self.selvitys = selvitys
        self.tulos = tulos
    }
}
