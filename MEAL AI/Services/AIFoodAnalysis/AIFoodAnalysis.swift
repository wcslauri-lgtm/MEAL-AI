import Foundation

final class AIFoodAnalysis {
    static let shared = AIFoodAnalysis()
    private init() {}

    private var provider: AIProviderService {
        switch UserDefaults.standard.selectedAIProvider {
        case .openAI: return OpenAIProviderService.shared
        case .claude: return ClaudeProviderService.shared
        case .gemini: return GeminiProviderService.shared
        }
    }

    func analyze(baseInfo: FoodBaseInfo?, query: String) async throws -> AIFoodAnalysisResult {
        var prompt = """
        User food query: \(query)
        Task: return nutrition for the consumed portion. Units in grams. If base values exist, refine them.
        Output: JSON with keys: meal_name, carbohydrates, protein, fat\(UserDefaults.standard.advancedDosingEnabled ? ", fatProteinUnits, netCarbsAdjustment, insulinTimingRecommendations, fpuDosingGuidance, exerciseConsiderations, absorptionTimeReasoning, mealSizeImpact, individualizationFactors, safetyAlerts" : "")
        """
        if let b = baseInfo {
            prompt += "\nKnown base: name=\(b.name), carbs=\(b.carbs ?? -1), protein=\(b.protein ?? -1), fat=\(b.fat ?? -1)."
        }
        return try await provider.analyze(prompt: prompt, imageData: nil)
    }

    func analyze(imageData: Data) async throws -> AIFoodAnalysisResult {
        let prompt = """
        Analyze the meal in the image. Estimate macronutrients (g) for the shown portion.
        Output STRICT JSON with keys: meal_name, carbohydrates, protein, fat\(UserDefaults.standard.advancedDosingEnabled ? ", fatProteinUnits, netCarbsAdjustment, insulinTimingRecommendations, fpuDosingGuidance, exerciseConsiderations, absorptionTimeReasoning, mealSizeImpact, individualizationFactors, safetyAlerts" : "")
        """
        return try await provider.analyze(prompt: prompt, imageData: imageData)
    }
}
