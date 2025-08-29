import Foundation

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case openAI, claude, gemini
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI (GPT-4/4o)"
        case .claude: return "Claude (Anthropic)"
        case .gemini: return "Gemini (Google)"
        }
    }
    var requiresImageSupport: Bool { self == .openAI || self == .gemini }
}

extension UserDefaults {
    private enum Keys {
        static let foodSearchEnabled = "foodSearchEnabled"
        static let selectedAIProvider = "selectedAIProvider"
        static let useNewAICamera = "useNewAICamera"
        static let advancedDosingEnabled = "advancedDosingEnabled"
        static let openAIKey = "openAIKey"
        static let claudeKey = "claudeKey"
        static let geminiKey = "geminiKey"
        static let usdaApiKey = "usdaApiKey"
    }

    var foodSearchEnabled: Bool {
        get { bool(forKey: Keys.foodSearchEnabled) }
        set { set(newValue, forKey: Keys.foodSearchEnabled) }
    }

    var selectedAIProvider: AIProvider {
        get {
            if let raw = string(forKey: Keys.selectedAIProvider),
               let p = AIProvider(rawValue: raw) { return p }
            return .openAI
        }
        set { set(newValue.rawValue, forKey: Keys.selectedAIProvider) }
    }

    var useNewAICamera: Bool {
        get { bool(forKey: Keys.useNewAICamera) }
        set { set(newValue, forKey: Keys.useNewAICamera) }
    }

    var advancedDosingEnabled: Bool {
        get { bool(forKey: Keys.advancedDosingEnabled) }
        set { set(newValue, forKey: Keys.advancedDosingEnabled) }
    }

    var openAIKey: String? {
        get { string(forKey: Keys.openAIKey) }
        set { set(newValue, forKey: Keys.openAIKey) }
    }

    var claudeKey: String? {
        get { string(forKey: Keys.claudeKey) }
        set { set(newValue, forKey: Keys.claudeKey) }
    }

    var geminiKey: String? {
        get { string(forKey: Keys.geminiKey) }
        set { set(newValue, forKey: Keys.geminiKey) }
    }

    var usdaApiKey: String? {
        get { string(forKey: Keys.usdaApiKey) }
        set { set(newValue, forKey: Keys.usdaApiKey) }
    }
}
