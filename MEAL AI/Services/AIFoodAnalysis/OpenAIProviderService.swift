import Foundation

final class OpenAIProviderService: AIProviderService {
    static let shared = OpenAIProviderService()
    private init() {}

    func analyze(prompt: String, imageData: Data?) async throws -> AIFoodAnalysisResult {
        guard let apiKey = UserDefaults.standard.openAIKey, !apiKey.isEmpty else {
            throw NSError(domain: "OpenAI", code: -10, userInfo: [NSLocalizedDescriptionKey: "OpenAI key missing"])
        }
        let api = OpenAIAPI(apiKey: apiKey)
        let sys = """
        You are a nutrition assistant for diabetes. Reply ONLY as valid JSON. Keys:
        meal_name (string, optional),
        carbohydrates (number, grams),
        protein (number, grams),
        fat (number, grams)
        \(UserDefaults.standard.advancedDosingEnabled ? ", fatProteinUnits, netCarbsAdjustment, insulinTimingRecommendations, fpuDosingGuidance, exerciseConsiderations, absorptionTimeReasoning, mealSizeImpact, individualizationFactors, safetyAlerts (strings, optional)" : "")
        """
        let raw = try await api.sendChat(
            model: .gpt4oMini,
            systemPrompt: sys,
            userPrompt: prompt,
            imageData: imageData,
            temperature: 0.0,
            maxCompletionTokens: 600,
            forceJSON: true
        )
        if let result: AIFoodAnalysisResult = MealAnalyzer.decodeJSON(from: raw) {
            return result
        }
        if let stage: StageMealResult = MealAnalyzer.decodeJSON(from: raw) {
            return AIFoodAnalysisResult(
                carbohydrates: stage.analysis.totals.carbs_g,
                protein: stage.analysis.totals.protein_g,
                fat: stage.analysis.totals.fat_g,
                mealName: stage.mealName,
                fatProteinUnits: nil, netCarbsAdjustment: nil, insulinTimingRecommendations: nil,
                fpuDosingGuidance: nil, exerciseConsiderations: nil, absorptionTimeReasoning: nil,
                mealSizeImpact: nil, individualizationFactors: nil, safetyAlerts: nil
            )
        }
        let cleaned = MealAnalyzer.sanitizeJSON(raw)
        if let result: AIFoodAnalysisResult = MealAnalyzer.decodeJSON(from: cleaned) { return result }
        if let stage: StageMealResult = MealAnalyzer.decodeJSON(from: cleaned) {
            return AIFoodAnalysisResult(
                carbohydrates: stage.analysis.totals.carbs_g,
                protein: stage.analysis.totals.protein_g,
                fat: stage.analysis.totals.fat_g,
                mealName: stage.mealName,
                fatProteinUnits: nil, netCarbsAdjustment: nil, insulinTimingRecommendations: nil,
                fpuDosingGuidance: nil, exerciseConsiderations: nil, absorptionTimeReasoning: nil,
                mealSizeImpact: nil, individualizationFactors: nil, safetyAlerts: nil
            )
        }
        throw NSError(domain: "OpenAI", code: -11, userInfo: [NSLocalizedDescriptionKey: "Cannot parse AI JSON"])
    }
}
