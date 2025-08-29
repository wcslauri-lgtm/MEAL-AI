
import SwiftUI

struct SettingsView: View {
    // MARK: - Yleiset asetukset
    @AppStorage("appLanguage") private var appLanguage: String = "FI" // "FI" | "EN"
    @AppStorage("preferSmallerOnCellular") private var preferSmallerOnCellular = false
    @AppStorage("showHintField") private var showHintField: Bool = true

    // MARK: - Shortcuts
    @AppStorage("shortcutEnabled") private var shortcutEnabled: Bool = true
    @AppStorage("shortcutName") private var shortcutName: String = ""
    @AppStorage("shortcutSendJSON") private var shortcutSendJSON: Bool = true

    // MARK: - Food Search (yhdistetty FoodSearchSettingsView)
    @AppStorage("foodSearchEnabled") private var foodSearchEnabled: Bool = false
    @AppStorage("aiAnalysisEnabled") private var aiAnalysisEnabled: Bool = false
    @AppStorage("aiProvider") private var aiProvider: String = "openai" // openai | claude | gemini
    @AppStorage("advancedDosingEnabled") private var advancedDosingEnabled: Bool = false
    @AppStorage("voiceSearchEnabled") private var voiceSearchEnabled: Bool = true
    @AppStorage("cameraAnalysisEnabled") private var cameraAnalysisEnabled: Bool = true
    @AppStorage("barcodePriorityEnabled") private var barcodePriorityEnabled: Bool = true

    // API-avaimet (säilötään Keychainiin)
    @State private var openAIKey: String = KeychainHelper.shared.get("openai_api_key") ?? ""
    @State private var claudeKey: String = KeychainHelper.shared.get("claude_api_key") ?? ""
    @State private var geminiKey: String = KeychainHelper.shared.get("gemini_api_key") ?? ""

    // Testi
    @State private var testingConnection = false
    @State private var testResult: String? = nil

    var body: some View {
        Form {
            // MARK: - Food Search
            Section {
                Toggle(loc("Ota käyttöön", en: "Enable"), isOn: $foodSearchEnabled)
                    .tint(.blue)

                Toggle(loc("AI-analyysi", en: "AI Analysis"), isOn: $aiAnalysisEnabled)
                    .tint(.mint)
                    .disabled(!foodSearchEnabled)

                Picker(loc("AI-tarjoaja", en: "AI Provider"), selection: $aiProvider) {
                    Text("OpenAI").tag("openai")
                    Text("Claude").tag("claude")
                    Text("Gemini").tag("gemini")
                }
                .disabled(!foodSearchEnabled || !aiAnalysisEnabled)
                .pickerStyle(.segmented)

                if foodSearchEnabled && aiAnalysisEnabled {
                    apiKeyEditor
                }

                Toggle(loc("Laajennetut annossuositukset (FPU)", en: "Advanced dosing recommendations (FPU)"),
                       isOn: $advancedDosingEnabled)
                    .disabled(!foodSearchEnabled || !aiAnalysisEnabled)
                    .tint(.blue)

                Toggle(loc("Äänihaku", en: "Voice search"), isOn: $voiceSearchEnabled)
                    .disabled(!foodSearchEnabled)
                Toggle(loc("Kamera-analyysi (AI Vision)", en: "Camera analysis (AI Vision)"),
                       isOn: $cameraAnalysisEnabled)
                    .disabled(!(foodSearchEnabled && aiAnalysisEnabled))
                Toggle(loc("Viivakoodille etusija", en: "Barcode priority"), isOn: $barcodePriorityEnabled)
                    .disabled(!foodSearchEnabled)
            } header: {
                Text("Food Search")
            }

            // MARK: - Kieli
            Section {
                Picker(loc("Sovelluksen kieli", en: "App language"), selection: $appLanguage) {
                    Text("Suomi").tag("FI")
                    Text("English").tag("EN")
                }
                .pickerStyle(.segmented)
            } header: {
                Text(loc("Kieli", en: "Language"))
            }

            // MARK: - Verkko
            Section {
                Toggle(isOn: $preferSmallerOnCellular) {
                    Text(loc("Pienempi kuva mobiiliverkossa", en: "Smaller photo on cellular"))
                }
                .help(loc("Säästää dataa etenkin ulkomailla.", en: "Saves data, especially when roaming."))
            } header: {
                Text("Verkko")
            }

            // MARK: - Käyttöliittymä
            Section {
                Toggle(loc("Näytä lisävihje-kenttä", en: "Show optional hint field"), isOn: $showHintField)

                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("Valokuvausvinkit", en: "Photo tips"))
                        .font(.subheadline).bold()
                    Text(loc(
                        "Parhaan tuloksen saat, kun kuvaat annoksen ylhäältä tai ~45° kulmasta hyvässä valossa. Pidä koko lautanen kuvassa ja sisällytä mittakaava (haarukka, käsi). Vältä liike-epäterävyyttä.",
                        en: "For best results, shoot from top-down or ~45° with good lighting. Keep the whole plate in view and include a scale cue (fork, hand). Avoid motion blur and ensure focus."
                    ))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text(loc("Käyttöliittymä", en: "Interface"))
            }

            // MARK: - Shortcuts
            Section {
                Toggle(loc("Näytä pikakuvake yläpalkissa", en: "Show Shortcut button"), isOn: $shortcutEnabled)

                TextField(
                    loc("Shortcuttin nimi (esim. 'Play Spotify')", en: "Shortcut name (e.g. 'Play Spotify')"),
                    text: $shortcutName
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

                Toggle(loc("Lähetä makrot JSON‑inputtina", en: "Send macros as JSON input"), isOn: $shortcutSendJSON)

                Text(loc(
                    "Kun tämä on päällä, sovellus välittää Shortcutille JSON‑objektin: { \"carbs\": 00, \"fat\": 00, \"protein\": 00 }. Shortcutsissa käytä toimintoa “Get Dictionary from Input”.",
                    en: "When enabled, the app passes a JSON object to the Shortcut: { \"carbs\": 00, \"fat\": 00, \"protein\": 00 }. In Shortcuts, use “Get Dictionary from Input”."
                ))
                .font(.footnote)
                .foregroundColor(.secondary)
            } header: {
                Text("Shortcuts")
            }
        }
        .navigationTitle(loc("Asetukset", en: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - API Key Editor
    @ViewBuilder
    private var apiKeyEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch aiProvider {
            case "openai":
                SecureField("OpenAI API key (sk-…)", text: $openAIKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: openAIKey) { _, v in KeychainHelper.shared.set(v, for: "openai_api_key") }
            case "claude":
                SecureField("Claude API key (sk-ant-…)", text: $claudeKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: claudeKey) { _, v in KeychainHelper.shared.set(v, for: "claude_api_key") }
            case "gemini":
                SecureField("Gemini API key", text: $geminiKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: geminiKey) { _, v in KeychainHelper.shared.set(v, for: "gemini_api_key") }
            default:
                EmptyView()
            }

            HStack {
                Button {
                    Task { await testConnectionTapped() }
                } label: {
                    if testingConnection {
                        ProgressView()
                    } else {
                        Text(loc("Testaa API‑yhteys", en: "Test API connection"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(testingConnection)

                if let res = testResult {
                    Text(res)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Connection test (vain OpenAI toteutettu tässä demossa)
    private func testConnectionTapped() async {
        testingConnection = true
        defer { testingConnection = false }
        testResult = nil

        if aiProvider == "openai" {
            let key = KeychainHelper.shared.get("openai_api_key") ?? ""
            guard key.starts(with: "sk-"), key.count > 20 else {
                testResult = loc("Virheellinen avain", en: "Invalid key")
                return
            }
            let api = OpenAIAPI(apiKey: key)
            do {
                _ = try await api.sendChat(
                    model: .gpt4oMini,
                    systemPrompt: "healthcheck",
                    userPrompt: "ping",
                    imageData: nil,
                    temperature: 0.0,
                    maxCompletionTokens: 5,
                    forceJSON: false
                )
                testResult = loc("OK ✅", en: "OK ✅")
            } catch {
                testResult = loc("Virhe: ", en: "Error: ") + (error.localizedDescription)
            }
        } else {
            testResult = loc("Malliprojektissa testataan vain OpenAI.", en: "Demo tests OpenAI only.")
        }
    }

    // MARK: - Helpers
    private func explainQuality(_ mode: String) -> String {
        switch mode {
        case "premium":
            return loc(
                "Premium: AI arvioi painot ja sovellus laskee makrot koodilla. Sisältää laajan selityksen ja per 100 g ‑arvion.",
                en: "Premium: AI estimates component weights; the app computes macros deterministically. Includes rich explanation and per‑100 g values."
            )
        case "high":
            return loc(
                "High: AI antaa erittelyn ja selityksen (painot arvioidaan), makrot suoraan mallilta.",
                en: "High: AI provides a breakdown and explanation (weights estimated), macros directly from the model."
            )
        default:
            return loc(
                "Normal: Nopea ja kustannustehokas – suorat makrot mallilta, ytimekäs tulos.",
                en: "Normal: Fast and cost‑effective – direct macros from the model, concise result."
            )
        }
    }

    private func loc(_ fi: String, en: String? = nil) -> String {
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "FI"
        if lang == "FI" { return fi }
        return en ?? fi
    }
}
