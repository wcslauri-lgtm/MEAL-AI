import Foundation

struct StageMealResult: Codable {
    let mealName: String?         // <- uusi, vapaaehtoinen
    let analysis: MealAnalysis

    enum CodingKeys: String, CodingKey {
        case mealName = "meal_name"
        case analysis
    }
}

struct MealAnalysis: Codable {
    let totals: MealTotals
}

struct MealTotals: Codable {
    let carbs_g: Double
    let protein_g: Double
    let fat_g: Double
}
