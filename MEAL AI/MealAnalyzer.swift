import Foundation
import UIKit

/// Yhden analyysitason analysoija (High).
/// Käyttää aina MealPrompts.stageSystem + MealPrompts.stageUser.
final class MealAnalyzer {

    static let shared = MealAnalyzer()

    // Käytetään kevyttä “vision”‑mallia kuvien kanssa; vaihda tarvittaessa.
    private let model: OpenAIModel = .gpt4oMini
    private let api: OpenAIAPI

    private init() {
        // Hyödynnetään samaa API‑avainta kuin muualla projektissa
        self.api = OpenAIAPI(apiKey: OPENAI_API_KEY)
    }

    /// Suorittaa analyysin annetusta kuvadatasta.
    /// Palauttaa `StageMealResult` + raakavastauksen (debug).
    func analyzeMeal(imageData: Data) async throws -> (StageMealResult, String) {

        // 1) Rakenna viestit – aina sama “High” (stage‑) promptti
        //    (User‑viesti sisältää vain ohjeen; varsinainen kuva liitetään API‑kutsun imageData‑parametrina)
        let systemPrompt = MealPrompts.stageSystem
        let userPrompt   = MealPrompts.stageUser

        // 2) Kutsu OpenAI
        let raw = try await api.sendChat(
            model: model,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            imageData: imageData,
            temperature: 0.0,              // deterministisempi JSON
            maxCompletionTokens: 900       // riittävä selitykselle + datalle
        )

        // 3) Tyhjien vastausten tarkistus
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "MealAnalyzer",
                          code: -10,
                          userInfo: [NSLocalizedDescriptionKey:
                                        "Empty content in response."])
        }

        // 4) JSONiksi -> StageMealResult
        if let decoded: StageMealResult = Self.decodeJSON(from: raw) {
            return (decoded, raw)
        }

        // 5) Yritä siivota ja dekoodata uudelleen (poista ```json aidat ym.)
        let cleaned = Self.sanitizeJSON(raw)
        if let decoded: StageMealResult = Self.decodeJSON(from: cleaned) {
            return (decoded, raw)
        }

        // 6) Epäonnistui
        throw NSError(domain: "MealAnalyzer",
                      code: -11,
                      userInfo: [NSLocalizedDescriptionKey:
                                    "Ei ollut validia JSONia. Vastauksen alku: \(raw.prefix(200))"])
    }
}

// MARK: - JSON helpers

extension MealAnalyzer {

    /// Poistaa yleiset “roskat”: ```json ‑aidat, markdownit, johtavat selitteet,
    /// sekä korjaa yleisimpiä “trailing comma” ‑virheitä.
    static func sanitizeJSON(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Poista koodiaidat ```json ... ``` tai ``` …
        if t.hasPrefix("```") {
            // jätä vain aito JSON‑lohko aitojen välistä
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

        // Poista mahdollinen zaczatek/koniec teksti aidan ulkopuolelta
        // Pidä vain ensimmäisestä “{” merkistä viimeiseen “}” merkkiin
        if let first = t.firstIndex(of: "{"), let last = t.lastIndex(of: "}") {
            t = String(t[first...last])
        }

        // Karkea trailing comma ‑ siivous: ", }" -> " }", ", ]" -> " ]"
        t = t.replacingOccurrences(of: #",\s*([\}\]])"#,
                                   with: "$1",
                                   options: .regularExpression)

        return t
    }

    /// Yrittää dekoodata annettuun tyyppiin.
    static func decodeJSON<T: Decodable>(from text: String) -> T? {
        // Ensin suoraan
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
