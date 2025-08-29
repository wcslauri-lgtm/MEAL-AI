import Foundation

final class GeminiProviderService: AIProviderService {
    static let shared = GeminiProviderService()
    private init() {}

    func analyze(prompt: String, imageData: Data?) async throws -> AIFoodAnalysisResult {
        guard let key = UserDefaults.standard.geminiKey, !key.isEmpty else {
            throw NSError(domain: "Gemini", code: -10, userInfo: [NSLocalizedDescriptionKey: "Gemini key missing"])
        }
        var comps = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent")!
        comps.queryItems = [.init(name: "key", value: key)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var parts: [[String: Any]] = [["text": prompt + "\nReturn ONLY valid JSON for AIFoodAnalysisResult"]]
        if let data = imageData {
            let base64 = data.base64EncodedString()
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": base64]])
        }
        let body: [String: Any] = ["contents": [["parts": parts]]]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gemini error"])
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = obj?["candidates"] as? [[String: Any]]
        let text = (((candidates?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]])?.first?["text"] as? String) ?? ""
        let cleaned = MealAnalyzer.sanitizeJSON(text)
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
        throw NSError(domain: "Gemini", code: -11, userInfo: [NSLocalizedDescriptionKey: "Cannot parse AI JSON"])
    }
}
