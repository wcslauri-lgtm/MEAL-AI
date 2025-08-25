import Foundation
import UIKit

/// Yhden analyysitason analysoija (High).
/// Käyttää aina MealPrompts.stageSystem + MealPrompts.stageUser.
final class MealAnalyzer {

    static let shared = MealAnalyzer()

    // Käytetään kevyttä “vision”-mallia kuvien kanssa; vaihda tarvittaessa.
    private let model: OpenAIModel = .gpt4oMini
    private let api: OpenAIAPI
    
    private struct TotalsOnlyDTO: Codable {
        let carbs_g: Double
        let protein_g: Double
        let fat_g: Double
    }


    private init() {
        // Hyödynnetään samaa API-avainta kuin muualla projektissa
        self.api = OpenAIAPI(apiKey: OPENAI_API_KEY)
    }

    /// Suorittaa analyysin annetusta kuvadatasta.
    /// Palauttaa `StageMealResult` + raakavastauksen (debug).
    func analyzeMeal(imageData: Data) async throws -> (StageMealResult, String) {

        // 🔹 0) peruutus heti alussa
        try Task.checkCancellation()

        // 1) Promptit
        let systemPrompt = MealPrompts.stageSystem
        let userPrompt   = MealPrompts.stageUser

        // 🔹 1.5) peruutus ennen verkkoa
        try Task.checkCancellation()

        // 2) Kutsu OpenAI (verkko-operaatio) — retry/backoff kääreessä
        let raw = try await withRetry {
            try await self.api.sendChat(
                model: self.model,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                imageData: imageData,
                temperature: 0.0,
                maxCompletionTokens: 120   // pienempi, koska palautamme vain 3 numeroa
            )
        }

        // 🔹 2.5) heti verkon jälkeen
        try Task.checkCancellation()

        // 3) Trimmaa ja tarkista tyhjä
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "MealAnalyzer", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "Empty content in response."])
        }

        // 🔹 3.5) peruutus ennen dekoodausta
        try Task.checkCancellation()

        // 4) Yritä ensin StageMealResult (analysis.totals-only -rakenne)
        if let decoded: StageMealResult = Self.decodeJSON(from: trimmed) {
            return (decoded, raw)
        }
        // 4b) Hyväksy pelkkä totals-objekti ja kääri se StageMealResultiksi
        if let t: TotalsOnlyDTO = Self.decodeJSON(from: trimmed) {
            let analysis = MealAnalysis(
                totals: MealTotals(carbs_g: t.carbs_g, protein_g: t.protein_g, fat_g: t.fat_g)
            )
            let sr = StageMealResult(analysis: analysis)
            return (sr, raw)
        }

        // 🔹 4.5) peruutus ennen sanitointia
        try Task.checkCancellation()

        // 5) Sanitointi (poista ```json -aidat yms.) ja uusi yritys
        let cleaned = Self.sanitizeJSON(trimmed)

        // 🔹 5.5) peruutus ennen toista dekoodausta
        try Task.checkCancellation()

        // 5a) StageMealResult sanitoinnin jälkeen
        if let decoded: StageMealResult = Self.decodeJSON(from: cleaned) {
            return (decoded, raw)
        }
        // 5b) TotalsOnlyDTO sanitoinnin jälkeen
        if let t: TotalsOnlyDTO = Self.decodeJSON(from: cleaned) {
            let analysis = MealAnalysis(
                totals: MealTotals(carbs_g: t.carbs_g, protein_g: t.protein_g, fat_g: t.fat_g)
            )
            let sr = StageMealResult(analysis: analysis)
            return (sr, raw)
        }

        // 6) Täsmällisempi virhe: onko JSON syntaktisesti validi vai oikeasti rikki?
        if let dataCheck = cleaned.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: dataCheck)) != nil {
            throw NSError(domain: "MealAnalyzer", code: -12,
                          userInfo: [NSLocalizedDescriptionKey:
                            "JSON ok, mutta skeema poikkeaa odotetusta. Alku: \(trimmed.prefix(200))"])
        } else {
            throw NSError(domain: "MealAnalyzer", code: -11,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Ei ollut validia JSONia. Vastauksen alku: \(trimmed.prefix(200))"])
        }
    }

    // MealAnalyzer-luokan sisään
    private func withRetry<T>(maxRetries: Int = 2, baseDelay: Double = 0.4, _ op: @escaping () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                return try await op()
            } catch {
                attempt += 1
                if attempt > maxRetries { throw error }
                let delay = baseDelay * pow(2.0, Double(attempt - 1)) // 0.4s, 0.8s, ...
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }
// MARK: - JSON helpers (pidetään luokan sisällä -> ei lipsu scope)
    /// Poistaa yleiset “roskat”: ```json -aidat, markdownit, johtavat selitteet,
    /// sekä korjaa yleisimpiä “trailing comma” -virheitä.
    static func sanitizeJSON(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Poista koodiaidat ```json ... ``` tai ``` …
        if t.hasPrefix("```") {
            if let r = t.range(of: #"```(?:json)?\s*"#, options: .regularExpression) {
                t.removeSubrange(r)
            }
            if let r2 = t.range(of: #"```"#, options: .regularExpression) {
                t.removeSubrange(r2)
            }
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Jos vastaus alkaa esim. “json\n{…}”, tiputetaan prefixi pois
        if let r = t.range(of: #"^\s*json\s*"#, options: .regularExpression) {
            t.removeSubrange(r)
        }

        // Pidä vain ensimmäisestä “{” merkistä viimeiseen “}” merkkiin
        if let first = t.firstIndex(of: "{"), let last = t.lastIndex(of: "}") {
            t = String(t[first...last])
        }

        // Karkea trailing comma - siivous: ", }" -> " }", ", ]" -> " ]"
        t = t.replacingOccurrences(of: #",\s*([\}\]])"#,
                                   with: "$1",
                                   options: .regularExpression)

        return t
    }

    /// Yrittää dekoodata annettuun tyyppiin.
    static func decodeJSON<T: Decodable>(from text: String) -> T? {
        if let data = text.data(using: .utf8) {
            if let obj = try? JSONDecoder().decode(T.self, from: data) {
                return obj
            }
        }
        // Jos mukana on BOM tai muuta roskaa, yritetään puhdistaa ja dekoodata uudelleen
        let cleaned = text.replacingOccurrences(of: "\u{feff}", with: "")
        if let data2 = cleaned.data(using: .utf8) {
            return try? JSONDecoder().decode(T.self, from: data2)
        }
        return nil
    }
}
