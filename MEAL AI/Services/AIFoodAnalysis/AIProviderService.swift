import Foundation

protocol AIProviderService {
    func analyze(prompt: String, imageData: Data?) async throws -> AIFoodAnalysisResult
}
