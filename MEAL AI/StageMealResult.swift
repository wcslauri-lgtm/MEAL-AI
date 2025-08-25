import Foundation

// Esimerkkityypit – pidä nimet kuten teillä, lisää vain init(from:) jossa defaultit

struct StageMealResult: Codable {
    var selvitys: String           // voi puuttua
    var reasoning: String          // voi puuttua
    var analysis: MealAnalysis     // vaaditaan (mutta sen sisällä on optionaaleja)

    enum CodingKeys: String, CodingKey { case selvitys, reasoning, analysis }

    init(selvitys: String = "", reasoning: String = "", analysis: MealAnalysis) {
        self.selvitys = selvitys
        self.reasoning = reasoning
        self.analysis = analysis
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // jos malli ei palauta näitä, defaultiksi tyhjä merkkijono
        self.selvitys  = (try? c.decode(String.self, forKey: .selvitys))  ?? ""
        self.reasoning = (try? c.decode(String.self, forKey: .reasoning)) ?? ""
        self.analysis  = try c.decode(MealAnalysis.self, forKey: .analysis)
    }
}

struct MealAnalysis: Codable {
    var totals: MealTotals                 // useimmiten on oltava
    var per100g: MealTotals?              // voi puuttua
    var foods: [MealFoodItem]?            // voi puuttua

    enum CodingKeys: String, CodingKey { case totals, per100g, foods }

    init(totals: MealTotals, per100g: MealTotals? = nil, foods: [MealFoodItem]? = nil) {
        self.totals = totals
        self.per100g = per100g
        self.foods = foods
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.totals  = try c.decode(MealTotals.self, forKey: .totals)
        self.per100g = try? c.decode(MealTotals.self, forKey: .per100g)
        self.foods   = try? c.decode([MealFoodItem].self, forKey: .foods)
    }
}

struct MealTotals: Codable {
    var carbs_g: Double
    var fat_g: Double
    var protein_g: Double
}

struct MealFoodItem: Codable {
    var name: String
    var carbs_g: Double?
    var fat_g: Double?
    var protein_g: Double?
    var confidence: Double?
    var estimated_weight_g: Double?
    var notes: String?
}
