import Foundation

/// Sovellus tarvitsee vain kokonaismakrot.
/// Pidetään rakenne yhteensopivana ContentView’n kanssa: stageResult.analysis.totals.*
struct StageMealResult: Codable {
    let analysis: MealAnalysis
}

struct MealAnalysis: Codable {
    let totals: MealTotals
}

struct MealTotals: Codable {
    let carbs_g: Double
    let protein_g: Double
    let fat_g: Double
}
