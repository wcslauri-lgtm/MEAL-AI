import Foundation

final class ClaudeProviderService: AIProviderService {
    static let shared = ClaudeProviderService()
    private init() {}

    func analyze(prompt: String, imageData: Data?) async throws -> AIFoodAnalysisResult {
        guard let key = UserDefaults.standard.claudeKey, !key.isEmpty else {
            throw NSError(domain: "Claude", code: -10, userInfo: [NSLocalizedDescriptionKey: "Claude key missing"])
        }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1200,
            "messages": [
                ["role": "user", "content": prompt + "\nRespond strictly as JSON matching AIFoodAnalysisResult keys."]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "Claude", code: -1, userInfo: [NSLocalizedDescriptionKey: "Claude error"])
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = ((obj?["content"] as? [[String: Any]])?.first?["text"] as? String) ?? ""
        let cleaned = MealAnalyzer.sanitizeJSON(content)
        if let res: AIFoodAnalysisResult = MealAnalyzer.decodeJSON(from: cleaned) { return res }
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
        throw NSError(domain: "Claude", code: -11, userInfo: [NSLocalizedDescriptionKey: "Cannot parse AI JSON"])
    }
}
