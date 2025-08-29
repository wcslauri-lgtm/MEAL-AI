import Foundation

struct AIFoodAnalysisResult: Codable {
    let carbohydrates: Double?
    let protein: Double?
    let fat: Double?
    let mealName: String?

    let fatProteinUnits: String?
    let netCarbsAdjustment: String?
    let insulinTimingRecommendations: String?
    let fpuDosingGuidance: String?
    let exerciseConsiderations: String?
    let absorptionTimeReasoning: String?
    let mealSizeImpact: String?
    let individualizationFactors: String?
    let safetyAlerts: String?
}
