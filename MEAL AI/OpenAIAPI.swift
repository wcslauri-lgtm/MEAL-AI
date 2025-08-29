
import Foundation

enum OpenAIModel: String {
    case gpt4oMini = "gpt-4o-mini"
    case gpt5      = "gpt-5"
    case gpt5Mini  = "gpt-5-mini"
    case gpt5Nano  = "gpt-5-nano"
}

final class OpenAIAPI {
    var apiKey: String
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 120
        cfg.timeoutIntervalForResource = 240
        self.session = URLSession(configuration: cfg)
    }

    func sendChat(
        model: OpenAIModel,
        systemPrompt: String,
        userPrompt: String,
        imageData: Data? = nil,
        temperature: Double = 0.0,
        maxCompletionTokens: Int = 900,
        forceJSON: Bool = true
    ) async throws -> String {

        try Task.checkCancellation()

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        if let imageData = imageData {
            try Task.checkCancellation()

            let base64 = imageData.base64EncodedString()

            let textPart: [String: Any]  = ["type": "text", "text": userPrompt]
            let imagePart: [String: Any] = [
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
            ]
            messages.append([
                "role": "user",
                "content": [textPart, imagePart]
            ])
        } else {
            messages.append([
                "role": "user",
                "content": userPrompt
            ])
        }

        var body: [String: Any] = [
            "model": model.rawValue,
            "messages": messages,
            "max_completion_tokens": maxCompletionTokens
        ]

        if forceJSON {
            body["response_format"] = ["type": "json_object"]
        }
        if model == .gpt4oMini {
            body["temperature"] = max(0.0, min(1.5, temperature))
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        try Task.checkCancellation()

        let (data, resp) = try await session.data(for: req)

        try Task.checkCancellation()

        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }
        guard (200...299).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "OpenAIAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: raw])
        }

        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = (obj?["choices"] as? [[String: Any]]) ?? []
        guard let message = choices.first?["message"] as? [String: Any] else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "OpenAIAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty choices.message. Raw: \(raw.prefix(400))"])
        }

        if let text = message["content"] as? String,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let parts = message["content"] as? [[String: Any]] {
            let collected = parts.compactMap { part -> String? in
                if let t = part["text"] as? String { return t }
                if let t = part["output_text"] as? String { return t }
                return nil
            }.joined(separator: "\n")
            if !collected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return collected.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let single = message["content"] as? [String: Any] {
            if let t = single["text"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return t.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let t = single["output_text"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return t.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let rawStr = String(data: data, encoding: .utf8) ?? ""
        throw NSError(
            domain: "OpenAIAPI",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "Empty content in response. Raw: \(rawStr.prefix(800))"]
        )
    }
}
